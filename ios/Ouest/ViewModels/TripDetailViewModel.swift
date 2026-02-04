import Foundation
import SwiftUI

// MARK: - Trip Detail ViewModel

@MainActor
final class TripDetailViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var trip: Trip
    @Published private(set) var expenses: [Expense] = []
    @Published private(set) var members: [TripMember] = []
    @Published private(set) var debts: [Debt] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Dependencies

    private let tripRepository: any TripRepositoryProtocol
    private let expenseRepository: any ExpenseRepositoryProtocol
    private let tripMemberRepository: any TripMemberRepositoryProtocol
    private var expenseSubscription: (any Cancellable)?

    // MARK: - Computed Properties

    var totalBudget: Decimal {
        trip.budget ?? 0
    }

    var totalSpent: Decimal {
        expenses.totalSpent
    }

    var remaining: Decimal {
        totalBudget - totalSpent
    }

    var spentPercentage: Double {
        guard totalBudget > 0 else { return 0 }
        return Double(truncating: (totalSpent / totalBudget) as NSDecimalNumber)
    }

    var isOverBudget: Bool {
        remaining < 0
    }

    var expensesByCategory: [ExpenseCategory: [Expense]] {
        Dictionary(grouping: expenses, by: { $0.category })
    }

    // MARK: - Initialization

    init(
        trip: Trip,
        tripRepository: any TripRepositoryProtocol,
        expenseRepository: any ExpenseRepositoryProtocol,
        tripMemberRepository: any TripMemberRepositoryProtocol
    ) {
        self.trip = trip
        self.tripRepository = tripRepository
        self.expenseRepository = expenseRepository
        self.tripMemberRepository = tripMemberRepository
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadExpenses() }
            group.addTask { await self.loadMembers() }
        }

        calculateDebts()
        isLoading = false
    }

    private func loadExpenses() async {
        do {
            expenses = try await expenseRepository.getExpenses(tripId: trip.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMembers() async {
        do {
            members = try await tripMemberRepository.getMembers(tripId: trip.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func calculateDebts() {
        debts = expenses.calculateDebts(members: members, currency: trip.currency)
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Real-time Updates

    func startObserving() {
        expenseSubscription = expenseRepository.observeExpenses(tripId: trip.id) { [weak self] updatedExpenses in
            Task { @MainActor in
                self?.expenses = updatedExpenses
                self?.calculateDebts()
            }
        }
    }

    func stopObserving() {
        expenseSubscription?.cancel()
        expenseSubscription = nil
    }

    // MARK: - Trip Actions

    func updateTrip(_ request: UpdateTripRequest) async {
        do {
            trip = try await tripRepository.updateTrip(id: trip.id, request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Expense Actions

    func addExpense(_ request: CreateExpenseRequest) async {
        isLoading = true

        do {
            let expense = try await expenseRepository.createExpense(request)
            expenses.insert(expense, at: 0)
            calculateDebts()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteExpense(_ expense: Expense) async {
        do {
            try await expenseRepository.deleteExpense(id: expense.id)
            expenses.removeAll { $0.id == expense.id }
            calculateDebts()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Member Actions

    func addMember(userId: String, role: MemberRole = .member) async {
        let request = CreateTripMemberRequest(
            tripId: trip.id,
            userId: userId,
            role: role
        )

        do {
            let member = try await tripMemberRepository.addMember(request)
            members.append(member)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeMember(_ member: TripMember) async {
        guard member.role != .owner else {
            error = "Cannot remove the trip owner"
            return
        }

        do {
            try await tripMemberRepository.removeMember(id: member.id)
            members.removeAll { $0.id == member.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
