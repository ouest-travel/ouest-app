import Foundation
import Supabase

// MARK: - Expense Repository Implementation

final class ExpenseRepository: ExpenseRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getExpenses(tripId: String) async throws -> [Expense] {
        let expenses: [Expense] = try await client
            .from(Tables.expenses)
            .select("*, paidByProfile:profiles!paid_by(id, email, display_name, handle, avatar_url, created_at)")
            .eq("trip_id", value: tripId)
            .order("date", ascending: false)
            .execute()
            .value

        return expenses
    }

    func createExpense(_ request: CreateExpenseRequest) async throws -> Expense {
        let expense: Expense = try await client
            .from(Tables.expenses)
            .insert(request)
            .select("*, paidByProfile:profiles!paid_by(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return expense
    }

    func updateExpense(id: String, _ request: CreateExpenseRequest) async throws -> Expense {
        let expense: Expense = try await client
            .from(Tables.expenses)
            .update(request)
            .eq("id", value: id)
            .select("*, paidByProfile:profiles!paid_by(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return expense
    }

    func deleteExpense(id: String) async throws {
        try await client
            .from(Tables.expenses)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func observeExpenses(tripId: String, onChange: @escaping ([Expense]) -> Void) -> any Cancellable {
        let channel = client.realtimeV2.channel("expenses_\(tripId)")

        Task {
            await channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: Tables.expenses,
                filter: "trip_id=eq.\(tripId)"
            ) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    do {
                        let expenses = try await self.getExpenses(tripId: tripId)
                        await MainActor.run {
                            onChange(expenses)
                        }
                    } catch {
                        print("Error fetching expenses: \(error)")
                    }
                }
            }

            await channel.subscribe()
        }

        return SubscriptionToken {
            Task {
                await channel.unsubscribe()
            }
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
