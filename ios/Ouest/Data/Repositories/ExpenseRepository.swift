import Foundation

// MARK: - Expense Repository Implementation (Local Storage)

final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let userDefaultsKey = "ouest_expenses"

    init() {}

    func getExpenses(tripId: String) async throws -> [Expense] {
        let expenses = loadExpenses()
        return expenses.filter { $0.tripId == tripId }
            .sorted { $0.date > $1.date }
    }

    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        var expenses = loadExpenses()

        let expense = Expense(
            id: UUID().uuidString,
            tripId: request.tripId,
            title: request.title,
            amount: request.amount,
            currency: request.currency,
            category: request.category,
            paidBy: request.paidBy,
            splitAmong: request.splitAmong,
            date: request.date,
            notes: request.notes,
            receiptUrl: request.receiptUrl,
            createdAt: Date(),
            paidByProfile: nil
        )

        expenses.append(expense)
        saveExpenses(expenses)

        return expense
    }

    func updateExpense(id: String, _ request: CreateExpenseRequest) async throws -> Expense {
        var expenses = loadExpenses()

        guard let index = expenses.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        let existing = expenses[index]
        let updated = Expense(
            id: existing.id,
            tripId: request.tripId,
            title: request.title,
            amount: request.amount,
            currency: request.currency,
            category: request.category,
            paidBy: request.paidBy,
            splitAmong: request.splitAmong,
            date: request.date,
            notes: request.notes,
            receiptUrl: request.receiptUrl,
            createdAt: existing.createdAt,
            paidByProfile: existing.paidByProfile
        )

        expenses[index] = updated
        saveExpenses(expenses)

        return updated
    }

    func deleteExpense(id: String) async throws {
        var expenses = loadExpenses()
        expenses.removeAll { $0.id == id }
        saveExpenses(expenses)
    }

    func observeExpenses(tripId: String, onChange: @escaping ([Expense]) -> Void) -> any Cancellable {
        // Local storage doesn't support real-time updates
        return SubscriptionToken { }
    }

    // MARK: - Private Storage Methods

    private func loadExpenses() -> [Expense] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([Expense].self, from: data)
        } catch {
            print("Failed to decode expenses: \(error)")
            return []
        }
    }

    private func saveExpenses(_ expenses: [Expense]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(expenses)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save expenses: \(error)")
        }
    }
}

// MARK: - Mock Expense Repository

final class MockExpenseRepository: ExpenseRepositoryProtocol {
    func getExpenses(tripId: String) async throws -> [Expense] {
        return DemoModeManager.demoExpenses.filter { $0.tripId == tripId }
    }

    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        try await Task.sleep(nanoseconds: 500_000_000)
        return DemoModeManager.demoExpenses[0]
    }

    func updateExpense(id: String, _ request: CreateExpenseRequest) async throws -> Expense {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard let expense = DemoModeManager.demoExpenses.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return expense
    }

    func deleteExpense(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func observeExpenses(tripId: String, onChange: @escaping ([Expense]) -> Void) -> any Cancellable {
        return SubscriptionToken { }
    }
}

// MARK: - Expense Calculations

extension Array where Element == Expense {
    /// Calculate total spent
    var totalSpent: Decimal {
        reduce(0) { $0 + $1.amount }
    }

    /// Calculate debts between members
    func calculateDebts(members: [TripMember], currency: String) -> [Debt] {
        var balances: [String: Decimal] = [:]

        // Initialize balances
        for member in members {
            balances[member.userId] = 0
        }

        // Calculate who paid what and who owes what
        for expense in self {
            let splitAmount = expense.amount / Decimal(expense.splitAmong.count)

            // Payer gets credit
            balances[expense.paidBy, default: 0] += expense.amount

            // Everyone who split owes their share
            for userId in expense.splitAmong {
                balances[userId, default: 0] -= splitAmount
            }
        }

        // Convert balances to debts
        var debts: [Debt] = []
        var creditors: [(String, Decimal)] = balances.filter { $0.value > 0.01 }.map { ($0.key, $0.value) }
        var debtors: [(String, Decimal)] = balances.filter { $0.value < -0.01 }.map { ($0.key, abs($0.value)) }

        // Match debtors to creditors
        while !creditors.isEmpty && !debtors.isEmpty {
            var creditor = creditors.removeFirst()
            var debtor = debtors.removeFirst()

            let amount = min(creditor.1, debtor.1)

            if let fromProfile = members.first(where: { $0.userId == debtor.0 })?.profile,
               let toProfile = members.first(where: { $0.userId == creditor.0 })?.profile {
                debts.append(Debt(from: fromProfile, to: toProfile, amount: amount, currency: currency))
            }

            creditor.1 -= amount
            debtor.1 -= amount

            if creditor.1 > 0.01 {
                creditors.insert(creditor, at: 0)
            }
            if debtor.1 > 0.01 {
                debtors.insert(debtor, at: 0)
            }
        }

        return debts
    }
}
