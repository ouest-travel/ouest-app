import Foundation
import Supabase

/// Handles all trip-related Supabase operations
enum TripService {

    // MARK: - Trip CRUD

    /// Fetch all trips the current user is a member of
    static func fetchMyTrips() async throws -> [Trip] {
        let userId = try await SupabaseManager.client.auth.session.user.id

        // Get trip IDs the user is a member of
        let memberRows: [TripMemberID] = try await SupabaseManager.client
            .from("trip_members")
            .select("trip_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        guard !memberRows.isEmpty else { return [] }

        let tripIds = memberRows.map(\.tripId)

        let trips: [Trip] = try await SupabaseManager.client
            .from("trips")
            .select()
            .in("id", values: tripIds)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return trips
    }

    /// Fetch a single trip by ID
    static func fetchTrip(id: UUID) async throws -> Trip {
        try await SupabaseManager.client
            .from("trips")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    /// Create a new trip
    static func createTrip(_ payload: CreateTripPayload) async throws -> Trip {
        try await SupabaseManager.client
            .from("trips")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update an existing trip
    static func updateTrip(id: UUID, _ payload: UpdateTripPayload) async throws -> Trip {
        try await SupabaseManager.client
            .from("trips")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    /// Delete a trip (owner only)
    static func deleteTrip(id: UUID) async throws {
        try await SupabaseManager.client
            .from("trips")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Trip Members

    /// Fetch members of a trip, with their profile data
    static func fetchMembers(tripId: UUID) async throws -> [TripMember] {
        try await SupabaseManager.client
            .from("trip_members")
            .select("*, profile:profiles!trip_members_user_id_fkey(*)")
            .eq("trip_id", value: tripId)
            .order("joined_at")
            .execute()
            .value
    }

    /// Add a member to a trip
    static func addMember(_ payload: AddMemberPayload) async throws -> TripMember {
        try await SupabaseManager.client
            .from("trip_members")
            .insert(payload)
            .select("*, profile:profiles!trip_members_user_id_fkey(*)")
            .single()
            .execute()
            .value
    }

    /// Update a member's role
    static func updateMemberRole(memberId: UUID, role: MemberRole) async throws {
        try await SupabaseManager.client
            .from("trip_members")
            .update(["role": role.rawValue])
            .eq("id", value: memberId)
            .execute()
    }

    /// Remove a member from a trip
    static func removeMember(memberId: UUID) async throws {
        try await SupabaseManager.client
            .from("trip_members")
            .delete()
            .eq("id", value: memberId)
            .execute()
    }

    /// Fetch lightweight member previews for multiple trips in one query (home screen)
    static func fetchMemberPreviews(tripIds: [UUID]) async throws -> [TripMemberPreview] {
        try await SupabaseManager.client
            .from("trip_members")
            .select("id, trip_id, user_id, role, profile:profiles!trip_members_user_id_fkey(avatar_url, full_name)")
            .in("trip_id", values: tripIds)
            .execute()
            .value
    }

    /// Search profiles by handle for inviting to a trip
    static func searchProfiles(query: String) async throws -> [Profile] {
        try await SupabaseManager.client
            .from("profiles")
            .select()
            .or("handle.ilike.%\(query)%,full_name.ilike.%\(query)%,email.ilike.%\(query)%")
            .limit(10)
            .execute()
            .value
    }

    /// Fetch public/discover trips for the Explore feed
    static func fetchPublicTrips(limit: Int = 20, offset: Int = 0) async throws -> [Trip] {
        try await SupabaseManager.client
            .from("trips")
            .select()
            .eq("is_public", value: true)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    /// Fetch a single profile by user ID
    static func fetchProfile(userId: UUID) async throws -> Profile {
        try await SupabaseManager.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    /// Fetch public trips by a specific user
    static func fetchUserPublicTrips(userId: UUID) async throws -> [Trip] {
        try await SupabaseManager.client
            .from("trips")
            .select()
            .eq("created_by", value: userId)
            .eq("is_public", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    // MARK: - Invite Links

    /// Generate a random 8-character invite code (base62, excludes confusable chars)
    static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    /// Create a new invite code for a trip
    static func createInvite(_ payload: CreateInvitePayload) async throws -> TripInvite {
        try await SupabaseManager.client
            .from("trip_invites")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Fetch all invites for a trip
    static func fetchInvites(tripId: UUID) async throws -> [TripInvite] {
        try await SupabaseManager.client
            .from("trip_invites")
            .select()
            .eq("trip_id", value: tripId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Revoke an invite (set is_active = false)
    static func revokeInvite(id: UUID) async throws {
        try await SupabaseManager.client
            .from("trip_invites")
            .update(["is_active": false])
            .eq("id", value: id)
            .execute()
    }

    /// Join a trip via invite code (atomic RPC). Returns the trip_id.
    static func joinViaInvite(code: String) async throws -> UUID {
        try await SupabaseManager.client
            .rpc("join_trip_via_invite", params: ["_code": code])
            .execute()
            .value
    }

    /// Validate/preview an invite code without joining.
    static func validateInvite(code: String) async throws -> InvitePreview {
        let results: [InvitePreview] = try await SupabaseManager.client
            .rpc("validate_invite", params: ["_code": code])
            .execute()
            .value
        guard let preview = results.first else {
            throw NSError(
                domain: "TripService", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Invalid invite code"]
            )
        }
        return preview
    }
}

// MARK: - Helper types for partial selects

private struct TripMemberID: Codable {
    let tripId: UUID
    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
    }
}
