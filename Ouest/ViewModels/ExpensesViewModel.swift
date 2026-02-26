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

    // MARK: - Trip Reference

    let trip: Trip
    private var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
    }

    // MARK: - Computed

    var isFormValid: Bool {
        let trimmed = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let amount = Double(expenseAmountText), amount > 0 else { return false }
        if splitType != .full && selectedMembers.isEmpty { return false }
        return true
    }

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

    /// Net balance per member across all expenses
    var memberBalances: [MemberBalance] {
        var paid: [UUID: Double] = [:]
        var owed: [UUID: Double] = [:]

        for expense in expenses {
            // Track who paid
            paid[expense.paidBy, default: 0] += expense.amount

            // Track who owes via splits
            if let splits = expense.splits {
                for split in splits {
                    owed[split.userId, default: 0] += split.amount
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
        guard let amount = Double(expenseAmountText), amount > 0 else { return false }
        isSaving = true

        let trimmedTitle = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let currency = trip.currency ?? "USD"

        do {
            if let editing = editingExpense {
                // Update existing expense
                let payload = UpdateExpensePayload(
                    title: trimmedTitle,
                    description: expenseDescription.isEmpty ? nil : expenseDescription,
                    amount: amount,
                    currency: currency,
                    category: expenseCategory,
                    date: expenseDate,
                    splitType: splitType
                )
                let updated = try await ExpensesService.updateExpense(id: editing.id, payload)

                // Re-create splits
                try await ExpensesService.deleteSplits(expenseId: editing.id)
                let splitPayloads = buildSplitPayloads(expenseId: editing.id, totalAmount: amount)
                try await ExpensesService.createSplits(splitPayloads)

                // Refresh the full expense to get nested data
                if let index = expenses.firstIndex(where: { $0.id == editing.id }) {
                    var refreshed = updated
                    refreshed.splits = try? await fetchSplitsForExpense(editing.id)
                    expenses[index] = refreshed
                }
            } else {
                // Create new expense
                let payload = CreateExpensePayload(
                    tripId: trip.id,
                    paidBy: userId,
                    title: trimmedTitle,
                    description: expenseDescription.isEmpty ? nil : expenseDescription,
                    amount: amount,
                    currency: currency,
                    category: expenseCategory,
                    date: expenseDate,
                    splitType: splitType
                )
                let created = try await ExpensesService.createExpense(payload)

                // Create splits
                let splitPayloads = buildSplitPayloads(expenseId: created.id, totalAmount: amount)
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
        editingExpense = nil
    }

    func populateFormFromExpense(_ expense: Expense) {
        editingExpense = expense
        expenseTitle = expense.title
        expenseDescription = expense.description ?? ""
        expenseAmountText = String(format: "%.2f", expense.amount)
        expenseCategory = expense.category
        expenseDate = expense.date ?? Date()
        splitType = expense.splitType

        // Populate selected members from existing splits
        if let splits = expense.splits {
            selectedMembers = Set(splits.map(\.userId))
            for split in splits {
                customSplits[split.userId] = String(format: "%.2f", split.amount)
            }
        }
    }

    /// Pre-select all members for a new expense
    func preselectAllMembers() {
        selectedMembers = Set(members.map(\.userId))
    }

    // MARK: - Private Helpers

    private func buildSplitPayloads(expenseId: UUID, totalAmount: Double) -> [CreateSplitPayload] {
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
                return CreateSplitPayload(expenseId: expenseId, userId: userId, amount: amount)
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
