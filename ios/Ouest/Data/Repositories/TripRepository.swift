import Foundation
import Supabase

// MARK: - Trip Repository Implementation

final class TripRepository: TripRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getUserTrips(userId: String) async throws -> [Trip] {
        // First get trip IDs where user is a member
        let memberships: [TripMember] = try await client
            .from(Tables.tripMembers)
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        let tripIds = memberships.map { $0.tripId }

        guard !tripIds.isEmpty else { return [] }

        // Then fetch the trips
        let trips: [Trip] = try await client
            .from(Tables.trips)
            .select("*, creator:profiles!trips_created_by_fkey(id, email, display_name, handle, avatar_url, created_at)")
            .in("id", values: tripIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        return trips
    }

    func getPublicTrips() async throws -> [Trip] {
        let trips: [Trip] = try await client
            .from(Tables.trips)
            .select("*, creator:profiles!trips_created_by_fkey(id, email, display_name, handle, avatar_url, created_at)")
            .eq("is_public", value: true)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value

        return trips
    }

    func getTrip(id: String) async throws -> Trip? {
        let trip: Trip? = try await client
            .from(Tables.trips)
            .select("*, creator:profiles!trips_created_by_fkey(id, email, display_name, handle, avatar_url, created_at)")
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return trip
    }

    func createTrip(_ request: CreateTripRequest) async throws -> Trip {
        let trip: Trip = try await client
            .from(Tables.trips)
            .insert(request)
            .select("*, creator:profiles!trips_created_by_fkey(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return trip
    }

    func updateTrip(id: String, _ request: UpdateTripRequest) async throws -> Trip {
        let trip: Trip = try await client
            .from(Tables.trips)
            .update(request)
            .eq("id", value: id)
            .select("*, creator:profiles!trips_created_by_fkey(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return trip
    }

    func deleteTrip(id: String) async throws {
        try await client
            .from(Tables.trips)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func observeTrips(userId: String, onChange: @escaping ([Trip]) -> Void) -> any Cancellable {
        let channel = client.realtimeV2.channel("trips_\(userId)")

        Task {
            await channel.onPostgresChange(
                AnyAction.self,
                schema: "public",
                table: Tables.trips
            ) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    do {
                        let trips = try await self.getUserTrips(userId: userId)
                        await MainActor.run {
                            onChange(trips)
                        }
                    } catch {
                        print("Error fetching trips: \(error)")
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

// MARK: - Mock Trip Repository for Demo Mode

final class MockTripRepository: TripRepositoryProtocol {
    func getUserTrips(userId: String) async throws -> [Trip] {
        return DemoModeManager.demoTrips
    }

    func getPublicTrips() async throws -> [Trip] {
        return DemoModeManager.demoTrips.filter { $0.isPublic }
    }

    func getTrip(id: String) async throws -> Trip? {
        return DemoModeManager.demoTrips.first { $0.id == id }
    }

    func createTrip(_ request: CreateTripRequest) async throws -> Trip {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        return DemoModeManager.demoTrips[0]
    }

    func updateTrip(id: String, _ request: UpdateTripRequest) async throws -> Trip {
        try await Task.sleep(nanoseconds: 500_000_000)
        guard let trip = DemoModeManager.demoTrips.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }
        return trip
    }

    func deleteTrip(id: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    func observeTrips(userId: String, onChange: @escaping ([Trip]) -> Void) -> any Cancellable {
        // Demo mode doesn't need real-time updates
        return SubscriptionToken { }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case notFound
    case unauthorized
    case networkError(Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The requested item was not found."
        case .unauthorized:
            return "You don't have permission to perform this action."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "The data received was invalid."
        }
    }
}
