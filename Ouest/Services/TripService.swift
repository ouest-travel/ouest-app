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
            .select("*, profile:profiles(*)")
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
            .select("*, profile:profiles(*)")
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
}

// MARK: - Helper types for partial selects

private struct TripMemberID: Codable {
    let tripId: UUID
    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
    }
}
