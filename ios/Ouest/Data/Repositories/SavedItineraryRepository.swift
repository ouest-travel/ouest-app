import Foundation

// MARK: - Saved Itinerary Repository Implementation (Local Storage)

final class SavedItineraryRepository: SavedItineraryRepositoryProtocol {
    private let userDefaultsKey = "ouest_saved_items"

    init() {}

    func getSavedItems(userId: String) async throws -> [SavedItineraryItem] {
        let items = loadItems()
        return items.filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func saveItem(_ request: CreateSavedItineraryItemRequest) async throws -> SavedItineraryItem {
        var items = loadItems()

        let item = SavedItineraryItem(
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

        items.append(item)
        saveItems(items)

        return item
    }

    func removeItem(id: String) async throws {
        var items = loadItems()
        items.removeAll { $0.id == id }
        saveItems(items)
    }

    // MARK: - Private Storage Methods

    private func loadItems() -> [SavedItineraryItem] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([SavedItineraryItem].self, from: data)
        } catch {
            print("Failed to decode saved items: \(error)")
            return []
        }
    }

    private func saveItems(_ items: [SavedItineraryItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save items: \(error)")
        }
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
