import Foundation

// MARK: - Trip Repository Implementation (Local Storage)

final class TripRepository: TripRepositoryProtocol {
    private let userDefaultsKey = "ouest_trips"
    private let membersKey = "ouest_trip_members"

    init() {}

    func getUserTrips(userId: String) async throws -> [Trip] {
        let trips = loadTrips()
        let members = loadMembers()

        // Get trip IDs where user is a member or creator
        let userTripIds = members
            .filter { $0.userId == userId }
            .map { $0.tripId }

        return trips.filter { userTripIds.contains($0.id) || $0.createdBy == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func getPublicTrips() async throws -> [Trip] {
        let trips = loadTrips()
        return trips.filter { $0.isPublic }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func getTrip(id: String) async throws -> Trip? {
        let trips = loadTrips()
        return trips.first { $0.id == id }
    }

    func createTrip(_ request: CreateTripRequest) async throws -> Trip {
        var trips = loadTrips()

        let trip = Trip(
            id: UUID().uuidString,
            name: request.name,
            destination: request.destination,
            startDate: request.startDate,
            endDate: request.endDate,
            budget: request.budget,
            currency: request.currency,
            createdBy: request.createdBy,
            isPublic: request.isPublic,
            votingEnabled: request.votingEnabled,
            coverImage: request.coverImage,
            description: request.description,
            status: request.status,
            createdAt: Date(),
            creator: nil
        )

        trips.append(trip)
        saveTrips(trips)

        // Auto-add creator as admin member
        var members = loadMembers()
        let member = TripMember(
            id: UUID().uuidString,
            tripId: trip.id,
            userId: request.createdBy,
            role: .admin,
            joinedAt: Date(),
            profile: nil
        )
        members.append(member)
        saveMembers(members)

        return trip
    }

    func updateTrip(id: String, _ request: UpdateTripRequest) async throws -> Trip {
        var trips = loadTrips()

        guard let index = trips.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        let existing = trips[index]
        let updated = Trip(
            id: existing.id,
            name: request.name ?? existing.name,
            destination: request.destination ?? existing.destination,
            startDate: request.startDate ?? existing.startDate,
            endDate: request.endDate ?? existing.endDate,
            budget: request.budget ?? existing.budget,
            currency: request.currency ?? existing.currency,
            createdBy: existing.createdBy,
            isPublic: request.isPublic ?? existing.isPublic,
            votingEnabled: request.votingEnabled ?? existing.votingEnabled,
            coverImage: request.coverImage ?? existing.coverImage,
            description: request.description ?? existing.description,
            status: request.status ?? existing.status,
            createdAt: existing.createdAt,
            creator: existing.creator
        )

        trips[index] = updated
        saveTrips(trips)

        return updated
    }

    func deleteTrip(id: String) async throws {
        var trips = loadTrips()
        trips.removeAll { $0.id == id }
        saveTrips(trips)

        // Also remove associated members
        var members = loadMembers()
        members.removeAll { $0.tripId == id }
        saveMembers(members)
    }

    func observeTrips(userId: String, onChange: @escaping ([Trip]) -> Void) -> any Cancellable {
        // Local storage doesn't support real-time updates
        // Return empty subscription
        return SubscriptionToken { }
    }

    // MARK: - Private Storage Methods

    private func loadTrips() -> [Trip] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([Trip].self, from: data)
        } catch {
            print("Failed to decode trips: \(error)")
            return []
        }
    }

    private func saveTrips(_ trips: [Trip]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(trips)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save trips: \(error)")
        }
    }

    private func loadMembers() -> [TripMember] {
        guard let data = UserDefaults.standard.data(forKey: membersKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([TripMember].self, from: data)
        } catch {
            print("Failed to decode members: \(error)")
            return []
        }
    }

    private func saveMembers(_ members: [TripMember]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(members)
            UserDefaults.standard.set(data, forKey: membersKey)
        } catch {
            print("Failed to save members: \(error)")
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
