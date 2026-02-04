import Foundation
import Supabase

// MARK: - Profile Repository Implementation

final class ProfileRepository: ProfileRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getProfile(userId: String) async throws -> Profile? {
        let profile: Profile = try await client
            .from(Tables.profiles)
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return profile
    }

    func updateProfile(userId: String, displayName: String?, handle: String?, avatarUrl: String?) async throws -> Profile {
        var updates: [String: AnyJSON] = [:]

        if let displayName = displayName {
            updates["display_name"] = .string(displayName)
        }
        if let handle = handle {
            updates["handle"] = .string(handle)
        }
        if let avatarUrl = avatarUrl {
            updates["avatar_url"] = .string(avatarUrl)
        }

        let profile: Profile = try await client
            .from(Tables.profiles)
            .update(updates)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value

        return profile
    }

    func getProfileStats(userId: String) async throws -> ProfileStats {
        // Get trips for countries visited count
        let trips: [Trip] = try await client
            .from(Tables.trips)
            .select("id, destination, status, end_date")
            .eq("created_by", value: userId)
            .execute()
            .value

        // Count unique destinations from completed/past trips
        let pastTrips = trips.filter { $0.isPastTrip }
        let uniqueDestinations = Set(pastTrips.map { $0.destination }).count

        // Count total trips
        let totalTrips = trips.count

        // Count expenses (memories)
        let tripIds = trips.map { $0.id }
        var memoriesCount = 0

        if !tripIds.isEmpty {
            // Note: Supabase Swift SDK count syntax
            let expenses: [Expense] = try await client
                .from(Tables.expenses)
                .select()
                .in("trip_id", values: tripIds)
                .execute()
                .value

            memoriesCount = expenses.count
        }

        // Count saved itineraries
        let savedItems: [SavedItineraryItem] = try await client
            .from(Tables.savedItineraryItems)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        return ProfileStats(
            countriesVisited: uniqueDestinations,
            totalTrips: totalTrips,
            memories: memoriesCount,
            savedItineraries: savedItems.count
        )
    }
}

// MARK: - Mock Profile Repository

final class MockProfileRepository: ProfileRepositoryProtocol {
    func getProfile(userId: String) async throws -> Profile? {
        return DemoModeManager.demoProfile
    }

    func updateProfile(userId: String, displayName: String?, handle: String?, avatarUrl: String?) async throws -> Profile {
        try await Task.sleep(nanoseconds: 500_000_000)
        return DemoModeManager.demoProfile
    }

    func getProfileStats(userId: String) async throws -> ProfileStats {
        return ProfileStats.demo
    }
}
