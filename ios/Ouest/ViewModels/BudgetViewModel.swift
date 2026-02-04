import Foundation
import SwiftUI

// MARK: - Budget ViewModel

@MainActor
final class BudgetViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var members: [TripMember] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Trip Data

    let trip: Trip

    // MARK: - Dependencies

    private let expenseRepository: any ExpenseRepositoryProtocol
    private let tripMemberRepository: any TripMemberRepositoryProtocol

    // MARK: - Initialization

    init(
        trip: Trip,
        expenseRepository: any ExpenseRepositoryProtocol,
        tripMemberRepository: any TripMemberRepositoryProtocol
    ) {
        self.trip = trip
        self.expenseRepository = expenseRepository
        self.tripMemberRepository = tripMemberRepository
    }

    // MARK: - Computed Properties

    var totalSpent: Decimal {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var remaining: Decimal {
        (trip.budget ?? 0) - totalSpent
    }

    var budgetProgress: Double {
        guard let budget = trip.budget, budget > 0 else { return 0 }
        let progress = NSDecimalNumber(decimal: totalSpent).doubleValue / NSDecimalNumber(decimal: budget).doubleValue
        return min(max(progress, 0), 1)
    }

    var isOverBudget: Bool {
        remaining < 0
    }

    var expensesByCategory: [ExpenseCategory: [Expense]] {
        Dictionary(grouping: expenses, by: { $0.category })
    }

    var categoryTotals: [(category: ExpenseCategory, total: Decimal)] {
        expensesByCategory.map { category, expenses in
            (category, expenses.reduce(0) { $0 + $1.amount })
        }.sorted { $0.total > $1.total }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadExpenses() }
            group.addTask { await self.loadMembers() }
        }

        isLoading = false
    }

    private func loadExpenses() async {
        do {
            expenses = try await expenseRepository.getExpenses(tripId: trip.id)
        } catch {
            self.error = error.localizedDescription
            print("Failed to load expenses: \(error)")
        }
    }

    private func loadMembers() async {
        do {
            members = try await tripMemberRepository.getMembers(tripId: trip.id)
        } catch {
            print("Failed to load members: \(error)")
        }
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Expense Actions

    func addExpense(_ request: CreateExpenseRequest) async {
        do {
            let expense = try await expenseRepository.createExpense(request)
            expenses.append(expense)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await expenseRepository.deleteExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
