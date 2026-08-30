import Foundation
import Observation

/// Manages expenses for a single trip (CRUD, splits, balances)
@MainActor @Observable
final class ExpensesViewModel {

    // MARK: - State

    var expenses: [Expense] = []
    var members: [TripMember] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    // MARK: - Navigation State

    var showAddExpense = false
    var showBalanceSummary = false
    var editingExpense: Expense?

    // MARK: - Form Fields

    var expenseTitle = ""
    var expenseDescription = ""
    var expenseAmountText = ""
    var expenseCategory: ExpenseCategory = .other
    var expenseDate = Date()
    var splitType: SplitType = .equal
    var selectedMembers: Set<UUID> = []
    var customSplits: [UUID: String] = [:]
    var receiptImageData: Data?

    /// Currency the user is entering this expense in. Defaults to the trip's
    /// currency; the picker can swap it to anything in `CommonCurrency.all`.
    /// On edit, this reflects the original currency the expense was paid in
    /// and the picker is locked so the frozen FX rate stays consistent.
    var expenseCurrency: String = "USD"

    /// Live FX rate fetched when `expenseCurrency != trip.currency`. Nil when
    /// no conversion is needed (same currency). Frozen into the row on save.
    var liveFXRate: Double?
    var isFetchingFXRate = false
    var fxFetchError: String?

    // MARK: - Trip Reference

    let trip: Trip
    private var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
        self.expenseCurrency = trip.currency ?? "USD"
    }

    // MARK: - Computed

    var isFormValid: Bool {
        let trimmed = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let amount = Double(expenseAmountText), amount > 0 else { return false }
        if splitType != .full && selectedMembers.isEmpty { return false }
        // If a foreign currency is picked we need the FX rate to be available
        // before save; otherwise we can't compute the trip-currency amount.
        if needsCurrencyConversion && liveFXRate == nil { return false }
        return true
    }

    /// True when the user picked a currency different from the trip's, which
    /// means a conversion (and live FX rate) is required at save time.
    var needsCurrencyConversion: Bool {
        let trip = (trip.currency ?? "USD").uppercased()
        return expenseCurrency.uppercased() != trip
    }

    /// Trip-currency equivalent of `expenseAmountText`, using the live rate.
    /// Returns nil when no conversion is needed or the rate hasn't loaded.
    var convertedAmountPreview: Double? {
        guard needsCurrencyConversion, let rate = liveFXRate else { return nil }
        guard let amount = Double(expenseAmountText), amount > 0 else { return nil }
        return amount * rate
    }

    /// "≈ $68.00 CAD" — preview string for the converted amount.
    var convertedAmountPreviewText: String? {
        guard let converted = convertedAmountPreview else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.currency ?? "USD"
        guard let formatted = formatter.string(from: NSNumber(value: converted)) else { return nil }
        return "≈ \(formatted)"
    }

    /// True iff the currency picker should be enabled. Locked in edit mode so
    /// the frozen FX rate stays coherent with the stored splits.
    var canEditCurrency: Bool { editingExpense == nil }

    var totalSpent: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var budgetRemaining: Double? {
        guard let budget = trip.budget, budget > 0 else { return nil }
        return budget - totalSpent
    }

    /// Fraction of budget spent (0...1+), nil if no budget
    var budgetProgress: Double? {
        guard let budget = trip.budget, budget > 0 else { return nil }
        return totalSpent / budget
    }

    var formattedTotalSpent: String {
        formatCurrency(totalSpent)
    }

    // MARK: - Balance Computation

    /// Net balance per member across all expenses.
    ///
    /// A settled split represents a reimbursement that's already happened
    /// (debtor paid the payer back outside the app). We cancel it from
    /// BOTH sides — the debtor no longer owes that amount AND the payer's
    /// effective outstanding "paid" drops by the same amount. The net effect
    /// is that the settled portion stops affecting either party's net
    /// balance, and the suggested-settlements computation no longer surfaces
    /// it as something still to resolve.
    var memberBalances: [MemberBalance] {
        var paid: [UUID: Double] = [:]
        var owed: [UUID: Double] = [:]

        for expense in expenses {
            paid[expense.paidBy, default: 0] += expense.amount

            if let splits = expense.splits {
                for split in splits {
                    owed[split.userId, default: 0] += split.amount

                    // Cancel out a reimbursement that's already happened.
                    // (The payer's split for their own expense doesn't count
                    // as a reimbursement — they "settled" with themselves.)
                    if split.isSettled && split.userId != expense.paidBy {
                        owed[split.userId, default: 0] -= split.amount
                        paid[expense.paidBy, default: 0] -= split.amount
                    }
                }
            }
        }

        // Build balances for all unique user IDs
        let allUserIds = Set(paid.keys).union(owed.keys)
        return allUserIds.compactMap { userId in
            let member = members.first(where: { $0.userId == userId })
            return MemberBalance(
                userId: userId,
                name: member?.profile?.fullName ?? "Unknown",
                avatarUrl: member?.profile?.avatarUrl,
                totalPaid: paid[userId, default: 0],
                totalOwed: owed[userId, default: 0]
            )
        }
        .sorted { $0.netBalance > $1.netBalance }
    }

    /// Minimize payments: greedy algorithm for who pays whom
    var settlements: [Settlement] {
        var debtors: [(MemberBalance, Double)] = []
        var creditors: [(MemberBalance, Double)] = []

        for balance in memberBalances {
            let net = balance.netBalance
            if net < -0.01 {
                debtors.append((balance, -net)) // positive amount they owe
            } else if net > 0.01 {
                creditors.append((balance, net)) // positive amount they're owed
            }
        }

        debtors.sort { $0.1 > $1.1 }
        creditors.sort { $0.1 > $1.1 }

        var result: [Settlement] = []
        var di = 0, ci = 0

        while di < debtors.count && ci < creditors.count {
            let amount = min(debtors[di].1, creditors[ci].1)
            if amount > 0.01 {
                result.append(Settlement(
                    from: debtors[di].0,
                    to: creditors[ci].0,
                    amount: amount
                ))
            }
            debtors[di].1 -= amount
            creditors[ci].1 -= amount
            if debtors[di].1 < 0.01 { di += 1 }
            if creditors[ci].1 < 0.01 { ci += 1 }
        }

        return result
    }

    // MARK: - Load

    func loadExpenses() async {
        isLoading = expenses.isEmpty
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            async let fetchedExpenses = ExpensesService.fetchExpenses(tripId: trip.id)
            async let fetchedMembers = TripService.fetchMembers(tripId: trip.id)
            expenses = try await fetchedExpenses
            members = try await fetchedMembers
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Save Expense

    func saveExpense() async -> Bool {
        guard let userId = currentUserId else { return false }
        guard let amountInput = Double(expenseAmountText), amountInput > 0 else { return false }
        isSaving = true

        let trimmedTitle = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let tripCurrency = trip.currency ?? "USD"

        // Resolve trip-currency amount + frozen FX fields up front. For
        // same-currency expenses these stay nil; for foreign-currency
        // expenses we lock today's rate (or the previously-frozen one when
        // editing) before any DB writes.
        let convertedAmount: Double
        let originalAmountForRow: Double?
        let originalCurrencyForRow: String?
        let fxRateForRow: Double?

        if needsCurrencyConversion {
            // Pull a rate now. In edit mode `liveFXRate` is the locked rate
            // from the original row; in create mode it should already have
            // been fetched by the picker, but re-fetch defensively if missing.
            var rate = liveFXRate
            if rate == nil {
                await refreshFXRate()
                rate = liveFXRate
            }
            guard let rate, rate > 0 else {
                fxFetchError = fxFetchError ?? "Couldn't fetch an exchange rate. Try again."
                HapticFeedback.error()
                isSaving = false
                return false
            }
            convertedAmount = amountInput * rate
            originalAmountForRow = amountInput
            originalCurrencyForRow = expenseCurrency.uppercased()
            fxRateForRow = rate
        } else {
            convertedAmount = amountInput
            originalAmountForRow = nil
            originalCurrencyForRow = nil
            fxRateForRow = nil
        }

        do {
            if let editing = editingExpense {
                // Upload receipt if provided
                var receiptUrl = editing.receiptUrl
                if let imageData = receiptImageData {
                    receiptUrl = try await StorageService.uploadReceipt(
                        data: imageData, tripId: trip.id, expenseId: editing.id
                    )
                }

                // Update existing expense
                let payload = UpdateExpensePayload(
                    title: trimmedTitle,
                    description: expenseDescription.isEmpty ? nil : expenseDescription,
                    amount: convertedAmount,
                    currency: tripCurrency,
                    originalAmount: originalAmountForRow,
                    originalCurrency: originalCurrencyForRow,
                    fxRate: fxRateForRow,
                    category: expenseCategory,
                    date: expenseDate,
                    splitType: splitType,
                    receiptUrl: receiptUrl
                )
                let updated = try await ExpensesService.updateExpense(id: editing.id, payload)

                // Re-create splits in trip currency (using the frozen rate
                // for foreign-currency expenses).
                try await ExpensesService.deleteSplits(expenseId: editing.id)
                let splitPayloads = buildSplitPayloads(
                    expenseId: editing.id,
                    totalAmount: convertedAmount,
                    fxRate: fxRateForRow
                )
                try await ExpensesService.createSplits(splitPayloads)

                // Refresh the full expense to get nested data
                if let index = expenses.firstIndex(where: { $0.id == editing.id }) {
                    var refreshed = updated
                    refreshed.splits = try? await fetchSplitsForExpense(editing.id)
                    expenses[index] = refreshed
                }
            } else {
                // Create new expense (no receipt yet — upload after we have the ID)
                let payload = CreateExpensePayload(
                    tripId: trip.id,
                    paidBy: userId,
                    title: trimmedTitle,
                    description: expenseDescription.isEmpty ? nil : expenseDescription,
                    amount: convertedAmount,
                    currency: tripCurrency,
                    originalAmount: originalAmountForRow,
                    originalCurrency: originalCurrencyForRow,
                    fxRate: fxRateForRow,
                    category: expenseCategory,
                    date: expenseDate,
                    splitType: splitType,
                    receiptUrl: nil
                )
                let created = try await ExpensesService.createExpense(payload)

                // Upload receipt if provided
                if let imageData = receiptImageData {
                    let receiptUrl = try await StorageService.uploadReceipt(
                        data: imageData, tripId: trip.id, expenseId: created.id
                    )
                    _ = try await ExpensesService.updateExpense(
                        id: created.id,
                        UpdateExpensePayload(receiptUrl: receiptUrl)
                    )
                }

                // Create splits
                let splitPayloads = buildSplitPayloads(
                    expenseId: created.id,
                    totalAmount: convertedAmount,
                    fxRate: fxRateForRow
                )
                try await ExpensesService.createSplits(splitPayloads)

                // Re-fetch to get nested split/profile data
                let fullExpenses = try await ExpensesService.fetchExpenses(tripId: trip.id)
                expenses = fullExpenses
            }

            HapticFeedback.success()
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
            isSaving = false
            return false
        }
    }

    // MARK: - Delete Expense

    func deleteExpense(_ expense: Expense) async {
        do {
            try await ExpensesService.deleteExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }
    }

    // MARK: - Settle / Unsettle

    func settleSplit(_ split: ExpenseSplit) async {
        do {
            try await ExpensesService.settleSplit(id: split.id)
            updateSplitLocally(splitId: split.id, settled: true)
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unsettleSplit(_ split: ExpenseSplit) async {
        do {
            try await ExpensesService.unsettleSplit(id: split.id)
            updateSplitLocally(splitId: split.id, settled: false)
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Every settled split rolled up by (debtor, payer) pair so the Balances
    /// view can render "Tim paid Dev · $95 · Undo" instead of listing each
    /// underlying split separately. Sorted latest-first for recency.
    var settledGroups: [SettledGroup] {
        struct Key: Hashable { let debtorId: UUID; let payerId: UUID }
        var groups: [Key: (amount: Double, splitIds: [UUID], latest: Date?)] = [:]

        for expense in expenses {
            guard let splits = expense.splits else { continue }
            for split in splits
            where split.isSettled && split.userId != expense.paidBy {
                let key = Key(debtorId: split.userId, payerId: expense.paidBy)
                var entry = groups[key] ?? (amount: 0, splitIds: [], latest: nil)
                entry.amount += split.amount
                entry.splitIds.append(split.id)
                if let existing = entry.latest, let this = split.settledAt {
                    entry.latest = max(existing, this)
                } else {
                    entry.latest = entry.latest ?? split.settledAt
                }
                groups[key] = entry
            }
        }

        return groups.compactMap { key, value -> SettledGroup? in
            let debtor = members.first(where: { $0.userId == key.debtorId })
            let payer = members.first(where: { $0.userId == key.payerId })
            return SettledGroup(
                debtorId: key.debtorId,
                debtorName: debtor?.profile?.fullName ?? "Unknown",
                debtorAvatarUrl: debtor?.profile?.avatarUrl,
                payerId: key.payerId,
                payerName: payer?.profile?.fullName ?? "Unknown",
                payerAvatarUrl: payer?.profile?.avatarUrl,
                amount: value.amount,
                splitIds: value.splitIds,
                latestSettledAt: value.latest
            )
        }
        .sorted {
            // Latest first, nils last.
            switch ($0.latestSettledAt, $1.latestSettledAt) {
            case let (a?, b?): return a > b
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return false
            }
        }
    }

    /// Reverse a settled group — flips is_settled = false on every underlying
    /// split. Symmetric to markSettlementPaid.
    func unsettleGroup(_ group: SettledGroup) async {
        HapticFeedback.medium()
        for splitId in group.splitIds {
            do {
                try await ExpensesService.unsettleSplit(id: splitId)
                updateSplitLocally(splitId: splitId, settled: false)
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedback.error()
                return
            }
        }
        HapticFeedback.success()
    }

    /// Mark a suggested settlement as paid. Settles every unsettled split
    /// where the debtor is the splitter AND the creditor is the expense payer
    /// — i.e., the direct splits that net to this settlement amount.
    ///
    /// Note: the greedy `settlements` algorithm can suggest amounts that route
    /// through intermediate parties (Tim owes Sarah indirectly because both
    /// share splits with Dev). For v1 we only auto-settle direct splits; any
    /// residual indirect amount stays in the suggestions list and the user
    /// can settle that via the separate Tim→Sarah card.
    func markSettlementPaid(_ settlement: Settlement) async {
        let debtorId = settlement.from.userId
        let creditorId = settlement.to.userId

        // Collect all matching unsettled splits first so the local updates
        // batch together cleanly (one re-render at the end).
        var toSettle: [ExpenseSplit] = []
        for expense in expenses where expense.paidBy == creditorId {
            guard let splits = expense.splits else { continue }
            for split in splits where split.userId == debtorId && !split.isSettled {
                toSettle.append(split)
            }
        }

        if toSettle.isEmpty {
            return
        }

        HapticFeedback.medium()

        for split in toSettle {
            do {
                try await ExpensesService.settleSplit(id: split.id)
                updateSplitLocally(splitId: split.id, settled: true)
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedback.error()
                return
            }
        }

        HapticFeedback.success()
    }

    // MARK: - Import Estimates from Itinerary

    /// Import estimated costs from itinerary activities as expenses.
    /// Only imports activities with costEstimate > 0. Skips duplicates by title.
    func importEstimatesFromItinerary() async -> Int {
        guard let userId = currentUserId else { return 0 }
        isSaving = true
        errorMessage = nil

        do {
            let days = try await ItineraryService.fetchDays(tripId: trip.id)
            let currency = trip.currency ?? "USD"
            var importedCount = 0

            let activitiesWithCosts = days.flatMap { day in
                (day.activities ?? []).filter { ($0.costEstimate ?? 0) > 0 }
            }

            let existingTitles = Set(expenses.map(\.title))

            for activity in activitiesWithCosts {
                guard !existingTitles.contains(activity.title) else { continue }

                let category: ExpenseCategory = switch activity.category {
                case .food: .food
                case .transport: .transport
                case .accommodation: .accommodation
                case .activity: .activity
                case .other: .other
                }

                let payload = CreateExpensePayload(
                    tripId: trip.id,
                    paidBy: userId,
                    title: activity.title,
                    description: "Estimated from itinerary",
                    amount: activity.costEstimate!,
                    currency: activity.currency ?? currency,
                    category: category,
                    date: nil,
                    splitType: .full,
                    receiptUrl: nil
                )

                _ = try await ExpensesService.createExpense(payload)
                importedCount += 1
            }

            if importedCount > 0 {
                expenses = try await ExpensesService.fetchExpenses(tripId: trip.id)
                HapticFeedback.success()
            }

            isSaving = false
            return importedCount
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
            isSaving = false
            return 0
        }
    }

    // MARK: - Form Lifecycle

    func resetForm() {
        expenseTitle = ""
        expenseDescription = ""
        expenseAmountText = ""
        expenseCategory = .other
        expenseDate = Date()
        splitType = .equal
        selectedMembers = []
        customSplits = [:]
        receiptImageData = nil
        editingExpense = nil
        expenseCurrency = trip.currency ?? "USD"
        liveFXRate = nil
        isFetchingFXRate = false
        fxFetchError = nil
    }

    func populateFormFromExpense(_ expense: Expense) {
        editingExpense = expense
        expenseTitle = expense.title
        expenseDescription = expense.description ?? ""
        expenseCategory = expense.category
        expenseDate = expense.date ?? Date()
        splitType = expense.splitType

        // For foreign-currency expenses, populate amount + splits in the
        // ORIGINAL currency the payer entered. The frozen FX rate stays
        // locked so we can re-convert on save without re-quoting.
        if let originalAmount = expense.originalAmount,
           let originalCurrency = expense.originalCurrency,
           let fxRate = expense.fxRate {
            expenseAmountText = String(format: "%.2f", originalAmount)
            expenseCurrency = originalCurrency
            liveFXRate = fxRate
        } else {
            expenseAmountText = String(format: "%.2f", expense.amount)
            expenseCurrency = expense.currency ?? trip.currency ?? "USD"
            liveFXRate = nil
        }

        // Populate selected members from existing splits. Reverse-convert
        // split amounts to the original currency when applicable.
        if let splits = expense.splits {
            selectedMembers = Set(splits.map(\.userId))
            for split in splits {
                let displayAmount: Double = {
                    guard let fx = liveFXRate, fx > 0, expense.originalAmount != nil else {
                        return split.amount
                    }
                    return split.amount / fx
                }()
                customSplits[split.userId] = String(format: "%.2f", displayAmount)
            }
        }
    }

    // MARK: - FX

    /// Fetch the rate to convert from `expenseCurrency` to the trip's
    /// currency. Clears the rate when no conversion is needed. Call this from
    /// the view whenever the currency picker changes.
    func refreshFXRate() async {
        // Edit mode keeps the frozen rate — never re-quote.
        if !canEditCurrency { return }
        guard needsCurrencyConversion else {
            liveFXRate = nil
            fxFetchError = nil
            return
        }
        let from = expenseCurrency
        let to = trip.currency ?? "USD"
        isFetchingFXRate = true
        fxFetchError = nil
        do {
            let rate = try await CurrencyService.fetchRate(from: from, to: to)
            // Only apply if the picker hasn't changed mid-flight.
            if expenseCurrency == from {
                liveFXRate = rate
            }
        } catch {
            liveFXRate = nil
            fxFetchError = error.localizedDescription
        }
        isFetchingFXRate = false
    }

    /// Pre-select all members for a new expense
    func preselectAllMembers() {
        selectedMembers = Set(members.map(\.userId))
    }

    // MARK: - Private Helpers

    /// Build split rows in the trip's currency. `totalAmount` is already
    /// converted to trip currency by the caller; for `.custom` splits the
    /// per-person entries are still in `expenseCurrency`, so we apply
    /// `fxRate` (when set) to convert each one.
    private func buildSplitPayloads(
        expenseId: UUID,
        totalAmount: Double,
        fxRate: Double?
    ) -> [CreateSplitPayload] {
        switch splitType {
        case .full:
            // No splits needed for full-amount expenses
            return []
        case .equal:
            let memberIds = Array(selectedMembers)
            guard !memberIds.isEmpty else { return [] }
            let perPerson = totalAmount / Double(memberIds.count)
            return memberIds.map {
                CreateSplitPayload(expenseId: expenseId, userId: $0, amount: perPerson)
            }
        case .custom:
            return selectedMembers.compactMap { userId in
                guard let amountStr = customSplits[userId],
                      let amount = Double(amountStr), amount > 0 else { return nil }
                let converted = (fxRate ?? 1.0) * amount
                return CreateSplitPayload(expenseId: expenseId, userId: userId, amount: converted)
            }
        }
    }

    private func updateSplitLocally(splitId: UUID, settled: Bool) {
        for (ei, expense) in expenses.enumerated() {
            guard let splits = expense.splits else { continue }
            for (si, split) in splits.enumerated() {
                if split.id == splitId {
                    expenses[ei].splits?[si].isSettled = settled
                    expenses[ei].splits?[si].settledAt = settled ? Date() : nil
                    return
                }
            }
        }
    }

    private func fetchSplitsForExpense(_ expenseId: UUID) async throws -> [ExpenseSplit] {
        try await SupabaseManager.client
            .from("expense_splits")
            .select("*, profile:profiles!expense_splits_user_id_fkey(*)")
            .eq("expense_id", value: expenseId)
            .execute()
            .value
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.currency ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
