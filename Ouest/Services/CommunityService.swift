import Foundation
import Supabase

/// Handles all community/social Supabase operations (likes, comments, follows, bookmarks, clone)
enum CommunityService {

    // MARK: - Feed Data (batch-efficient)

    /// Fetch creator profiles for a set of user IDs
    static func fetchCreatorProfiles(userIds: [UUID]) async throws -> [Profile] {
        guard !userIds.isEmpty else { return [] }
        return try await SupabaseManager.client
            .from("profiles")
            .select()
            .in("id", values: Array(Set(userIds))) // dedupe
            .execute()
            .value
    }

    /// Batch fetch like counts for trips
    static func fetchLikeCounts(tripIds: [UUID]) async throws -> [UUID: Int] {
        guard !tripIds.isEmpty else { return [:] }
        let likes: [TripLike] = try await SupabaseManager.client
            .from("trip_likes")
            .select("id, trip_id, user_id, created_at")
            .in("trip_id", values: tripIds)
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for like in likes {
            counts[like.tripId, default: 0] += 1
        }
        return counts
    }

    /// Batch fetch comment counts for trips
    static func fetchCommentCounts(tripIds: [UUID]) async throws -> [UUID: Int] {
        guard !tripIds.isEmpty else { return [:] }
        let comments: [TripComment] = try await SupabaseManager.client
            .from("trip_comments")
            .select("id, trip_id, user_id, content, created_at, updated_at")
            .in("trip_id", values: tripIds)
            .execute()
            .value
        var counts: [UUID: Int] = [:]
        for comment in comments {
            counts[comment.tripId, default: 0] += 1
        }
        return counts
    }

    /// Which of these trips has the user liked?
    static func fetchLikeStatus(tripIds: [UUID], userId: UUID) async throws -> Set<UUID> {
        guard !tripIds.isEmpty else { return [] }
        let likes: [TripLike] = try await SupabaseManager.client
            .from("trip_likes")
            .select()
            .in("trip_id", values: tripIds)
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(likes.map(\.tripId))
    }

    /// Which of these trips has the user saved?
    static func fetchSaveStatus(tripIds: [UUID], userId: UUID) async throws -> Set<UUID> {
        guard !tripIds.isEmpty else { return [] }
        let saves: [SavedTrip] = try await SupabaseManager.client
            .from("saved_trips")
            .select()
            .in("trip_id", values: tripIds)
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(saves.map(\.tripId))
    }

    // MARK: - Likes

    static func likeTrip(tripId: UUID, userId: UUID) async throws {
        let payload = CreateLikePayload(tripId: tripId, userId: userId)
        try await SupabaseManager.client
            .from("trip_likes")
            .insert(payload)
            .execute()
    }

    static func unlikeTrip(tripId: UUID, userId: UUID) async throws {
        try await SupabaseManager.client
            .from("trip_likes")
            .delete()
            .eq("trip_id", value: tripId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Comments

    static func fetchComments(tripId: UUID) async throws -> [TripComment] {
        try await SupabaseManager.client
            .from("trip_comments")
            .select("*, profile:profiles!trip_comments_user_id_fkey(*)")
            .eq("trip_id", value: tripId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func addComment(tripId: UUID, userId: UUID, content: String) async throws -> TripComment {
        let payload = CreateCommentPayload(tripId: tripId, userId: userId, content: content)
        return try await SupabaseManager.client
            .from("trip_comments")
            .insert(payload)
            .select("*, profile:profiles!trip_comments_user_id_fkey(*)")
            .single()
            .execute()
            .value
    }

    static func deleteComment(id: UUID) async throws {
        try await SupabaseManager.client
            .from("trip_comments")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Follows

    static func followUser(followingId: UUID, followerId: UUID) async throws {
        let payload = CreateFollowPayload(followerId: followerId, followingId: followingId)
        try await SupabaseManager.client
            .from("follows")
            .insert(payload)
            .execute()
    }

    static func unfollowUser(followingId: UUID, followerId: UUID) async throws {
        try await SupabaseManager.client
            .from("follows")
            .delete()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .execute()
    }

    /// Which of these user IDs is the current user following?
    static func fetchFollowStatus(userIds: [UUID], currentUserId: UUID) async throws -> Set<UUID> {
        guard !userIds.isEmpty else { return [] }
        let follows: [Follow] = try await SupabaseManager.client
            .from("follows")
            .select()
            .eq("follower_id", value: currentUserId)
            .in("following_id", values: userIds)
            .execute()
            .value
        return Set(follows.map(\.followingId))
    }

    static func fetchFollowerCount(userId: UUID) async throws -> Int {
        let follows: [Follow] = try await SupabaseManager.client
            .from("follows")
            .select()
            .eq("following_id", value: userId)
            .execute()
            .value
        return follows.count
    }

    static func fetchFollowingCount(userId: UUID) async throws -> Int {
        let follows: [Follow] = try await SupabaseManager.client
            .from("follows")
            .select()
            .eq("follower_id", value: userId)
            .execute()
            .value
        return follows.count
    }

    // MARK: - Bookmarks

    static func saveTrip(tripId: UUID, userId: UUID) async throws {
        let payload = CreateSavedTripPayload(userId: userId, tripId: tripId)
        try await SupabaseManager.client
            .from("saved_trips")
            .insert(payload)
            .execute()
    }

    static func unsaveTrip(tripId: UUID, userId: UUID) async throws {
        try await SupabaseManager.client
            .from("saved_trips")
            .delete()
            .eq("trip_id", value: tripId)
            .eq("user_id", value: userId)
            .execute()
    }

    static func fetchSavedTrips(userId: UUID) async throws -> [Trip] {
        // Fetch saved_trips, then fetch the actual trip data
        let saves: [SavedTrip] = try await SupabaseManager.client
            .from("saved_trips")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        guard !saves.isEmpty else { return [] }
        let tripIds = saves.map(\.tripId)

        return try await SupabaseManager.client
            .from("trips")
            .select()
            .in("id", values: tripIds)
            .execute()
            .value
    }

    // MARK: - Clone Trip

    /// Clone a public trip as a new draft for the given user
    static func cloneTrip(sourceTripId: UUID, newOwnerId: UUID) async throws -> Trip {
        // 1. Fetch source trip
        let source = try await TripService.fetchTrip(id: sourceTripId)

        // 2. Create new trip as draft
        let payload = CreateTripPayload(
            createdBy: newOwnerId,
            title: "\(source.title) (copy)",
            destination: source.destination,
            description: source.description,
            coverImageUrl: source.coverImageUrl,
            startDate: nil, // User will set their own dates
            endDate: nil,
            status: .planning,
            isPublic: false,
            budget: source.budget,
            currency: source.currency
        )
        let newTrip = try await TripService.createTrip(payload)

        // 3. Clone itinerary days + activities
        let days = try await ItineraryService.fetchDays(tripId: sourceTripId)
        for day in days {
            let dayPayload = CreateDayPayload(
                tripId: newTrip.id,
                dayNumber: day.dayNumber,
                date: nil, // No dates since trip has no dates yet
                title: day.title,
                notes: day.notes
            )
            let newDay = try await ItineraryService.createDay(dayPayload)

            // Clone activities for this day
            for activity in day.sortedActivities {
                let actPayload = CreateActivityPayload(
                    dayId: newDay.id,
                    title: activity.title,
                    description: activity.description,
                    locationName: activity.locationName,
                    latitude: activity.latitude,
                    longitude: activity.longitude,
                    startTime: activity.startTime,
                    endTime: activity.endTime,
                    category: activity.category,
                    costEstimate: activity.costEstimate,
                    currency: activity.currency,
                    sortOrder: activity.sortOrder,
                    createdBy: newOwnerId
                )
                _ = try await ItineraryService.createActivity(actPayload)
            }
        }

        return newTrip
    }
}
