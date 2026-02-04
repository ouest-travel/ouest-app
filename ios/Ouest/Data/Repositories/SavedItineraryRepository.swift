import Foundation
import Supabase

// MARK: - Saved Itinerary Repository Implementation

final class SavedItineraryRepository: SavedItineraryRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getSavedItems(userId: String) async throws -> [SavedItineraryItem] {
        let items: [SavedItineraryItem] = try await client
            .from(Tables.savedItineraryItems)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return items
    }

    func saveItem(_ request: CreateSavedItineraryItemRequest) async throws -> SavedItineraryItem {
        let item: SavedItineraryItem = try await client
            .from(Tables.savedItineraryItems)
            .insert(request)
            .select()
            .single()
            .execute()
            .value

        return item
    }

    func removeItem(id: String) async throws {
        try await client
            .from(Tables.savedItineraryItems)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Mock Saved Itinerary Repository

final class MockSavedItineraryRepository: SavedItineraryRepositoryProtocol {
    func getSavedItems(userId: String) async throws -> [SavedItineraryItem] {
        return DemoModeManager.demoSavedItems
    }

    func saveItem(_ request: CreateSavedItineraryItemRequest) async throws -> SavedItineraryItem {
        try await Task.sleep(nanoseconds: 300_000_000)
        return SavedItineraryItem(
            id: UUID().uuidString,
            userId: request.userId,
            activityName: request.activityName,
            activityLocation: request.activityLocation,
            activityTime: request.activityTime,
            activityCost: request.activityCost,
            activityDescription: request.activityDescription,
            activityCategory: request.activityCategory,
            sourceTripLocation: request.sourceTripLocation,
            sourceTripUser: request.sourceTripUser,
            day: request.day,
            createdAt: Date()
        )
    }

    func removeItem(id: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }
}
