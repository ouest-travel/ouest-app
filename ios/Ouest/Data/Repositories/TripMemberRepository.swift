import Foundation
import Supabase

// MARK: - Trip Member Repository Implementation

final class TripMemberRepository: TripMemberRepositoryProtocol {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    func getMembers(tripId: String) async throws -> [TripMember] {
        let members: [TripMember] = try await client
            .from(Tables.tripMembers)
            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
            .eq("trip_id", value: tripId)
            .execute()
            .value

        return members
    }

    func addMember(_ request: CreateTripMemberRequest) async throws -> TripMember {
        let member: TripMember = try await client
            .from(Tables.tripMembers)
            .insert(request)
            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return member
    }

    func removeMember(id: String) async throws {
        try await client
            .from(Tables.tripMembers)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateRole(memberId: String, role: MemberRole) async throws -> TripMember {
        let member: TripMember = try await client
            .from(Tables.tripMembers)
            .update(["role": role.rawValue])
            .eq("id", value: memberId)
            .select("*, profile:profiles!user_id(id, email, display_name, handle, avatar_url, created_at)")
            .single()
            .execute()
            .value

        return member
    }
}

// MARK: - Mock Trip Member Repository

final class MockTripMemberRepository: TripMemberRepositoryProtocol {
    func getMembers(tripId: String) async throws -> [TripMember] {
        // Create mock members from demo profiles
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
