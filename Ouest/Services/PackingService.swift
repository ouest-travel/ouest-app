import Foundation

// MARK: - Packing Service

enum PackingService {

    private static let itemSelect = "*, assignee:profiles!packing_items_assigned_to_fkey(*)"

    /// All items for a trip, oldest first so the list keeps a stable order
    /// as people tick things off.
    static func fetchItems(tripId: UUID) async throws -> [PackingItem] {
        try await SupabaseManager.client
            .from("packing_items")
            .select(itemSelect)
            .eq("trip_id", value: tripId)
            .order("created_at")
            .execute()
            .value
    }

    static func createItem(_ payload: CreatePackingItemPayload) async throws -> PackingItem {
        try await SupabaseManager.client
            .from("packing_items")
            .insert(payload)
            .select(itemSelect)
            .single()
            .execute()
            .value
    }

    /// Batch insert, used for the starter list.
    static func createItems(_ payloads: [CreatePackingItemPayload]) async throws -> [PackingItem] {
        try await SupabaseManager.client
            .from("packing_items")
            .insert(payloads)
            .select(itemSelect)
            .execute()
            .value
    }

    static func updateItem(id: UUID, _ payload: UpdatePackingItemPayload) async throws -> PackingItem {
        try await SupabaseManager.client
            .from("packing_items")
            .update(payload)
            .eq("id", value: id)
            .select(itemSelect)
            .single()
            .execute()
            .value
    }

    static func deleteItem(id: UUID) async throws {
        try await SupabaseManager.client
            .from("packing_items")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
