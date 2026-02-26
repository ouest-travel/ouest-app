import Foundation
import Supabase

/// Handles all expense-related Supabase operations
enum ExpensesService {

    /// Nested select for expenses with splits and payer profile
    private static let expenseSelect = "*, splits:expense_splits(*, profile:profiles!expense_splits_user_id_fkey(*)), paid_by_profile:profiles!expenses_paid_by_fkey(*)"

    // MARK: - Expenses

    /// Fetch all expenses for a trip, with nested splits and payer profile
    static func fetchExpenses(tripId: UUID) async throws -> [Expense] {
        try await SupabaseManager.client
            .from("expenses")
            .select(expenseSelect)
            .eq("trip_id", value: tripId)
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Create a new expense
    static func createExpense(_ payload: CreateExpensePayload) async throws -> Expense {
        try await SupabaseManager.client
            .from("expenses")
            .insert(payload)
            .select(expenseSelect)
            .single()
            .execute()
            .value
    }

    /// Update an existing expense
    static func updateExpense(id: UUID, _ payload: UpdateExpensePayload) async throws -> Expense {
        try await SupabaseManager.client
            .from("expenses")
            .update(payload)
            .eq("id", value: id)
            .select(expenseSelect)
            .single()
            .execute()
            .value
    }

    /// Delete an expense (cascades to splits)
    static func deleteExpense(id: UUID) async throws {
        try await SupabaseManager.client
            .from("expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Splits

    /// Batch-create splits for an expense
    static func createSplits(_ payloads: [CreateSplitPayload]) async throws {
        guard !payloads.isEmpty else { return }
        try await SupabaseManager.client
            .from("expense_splits")
            .insert(payloads)
            .execute()
    }

    /// Delete all splits for an expense (used before re-creating on edit)
    static func deleteSplits(expenseId: UUID) async throws {
        try await SupabaseManager.client
            .from("expense_splits")
            .delete()
            .eq("expense_id", value: expenseId)
            .execute()
    }

    /// Mark a single split as settled
    static func settleSplit(id: UUID) async throws {
        let payload = SettleSplitPayload(isSettled: true, settledAt: Date())
        try await SupabaseManager.client
            .from("expense_splits")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    /// Mark a single split as unsettled
    static func unsettleSplit(id: UUID) async throws {
        let payload = SettleSplitPayload(isSettled: false, settledAt: nil)
        try await SupabaseManager.client
            .from("expense_splits")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Internal Payload

private struct SettleSplitPayload: Codable {
    let isSettled: Bool
    let settledAt: Date?

    enum CodingKeys: String, CodingKey {
        case isSettled = "is_settled"
        case settledAt = "settled_at"
    }
}
