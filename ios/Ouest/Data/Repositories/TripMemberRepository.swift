import Foundation

// MARK: - Trip Member Repository Implementation (Local Storage)

final class TripMemberRepository: TripMemberRepositoryProtocol {
    private let userDefaultsKey = "ouest_trip_members"

    init() {}

    func getMembers(tripId: String) async throws -> [TripMember] {
        let members = loadMembers()
        return members.filter { $0.tripId == tripId }
    }

    func addMember(_ request: CreateTripMemberRequest) async throws -> TripMember {
        var members = loadMembers()

        let member = TripMember(
            id: UUID().uuidString,
            tripId: request.tripId,
            userId: request.userId,
            role: request.role,
            joinedAt: Date(),
            profile: nil
        )

        members.append(member)
        saveMembers(members)

        return member
    }

    func removeMember(id: String) async throws {
        var members = loadMembers()
        members.removeAll { $0.id == id }
        saveMembers(members)
    }

    func updateRole(memberId: String, role: MemberRole) async throws -> TripMember {
        var members = loadMembers()

        guard let index = members.firstIndex(where: { $0.id == memberId }) else {
            throw RepositoryError.notFound
        }

        let existing = members[index]
        let updated = TripMember(
            id: existing.id,
            tripId: existing.tripId,
            userId: existing.userId,
            role: role,
            joinedAt: existing.joinedAt,
            profile: existing.profile
        )

        members[index] = updated
        saveMembers(members)

        return updated
    }

    // MARK: - Private Storage Methods

    private func loadMembers() -> [TripMember] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
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
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save members: \(error)")
        }
    }
}

// MARK: - Mock Trip Member Repository

final class MockTripMemberRepository: TripMemberRepositoryProtocol {
    func getMembers(tripId: String) async throws -> [TripMember] {
        return DemoModeManager.demoMembers.enumerated().map { index, profile in
            TripMember(
                id: "member-\(index)",
                tripId: tripId,
                userId: profile.id,
                role: index == 0 ? .owner : .member,
                joinedAt: Date(),
                profile: profile
            )
        }
    }

    func addMember(_ request: CreateTripMemberRequest) async throws -> TripMember {
        try await Task.sleep(nanoseconds: 300_000_000)
        return TripMember(
            id: UUID().uuidString,
            tripId: request.tripId,
            userId: request.userId,
            role: request.role,
            joinedAt: Date(),
            profile: DemoModeManager.demoMembers.first
        )
    }

    func removeMember(id: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    func updateRole(memberId: String, role: MemberRole) async throws -> TripMember {
        try await Task.sleep(nanoseconds: 300_000_000)
        return TripMember(
            id: memberId,
            tripId: "demo-trip",
            userId: "demo-user",
            role: role,
            joinedAt: Date(),
            profile: DemoModeManager.demoMembers.first
        )
    }
}
