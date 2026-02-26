import Foundation
import Observation

/// Manages the community feed (public trips with social data)
@MainActor @Observable
final class CommunityFeedViewModel {

    // MARK: - State

    var feedTrips: [FeedTrip] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?

    // MARK: - Search

    var searchQuery = ""

    var filteredTrips: [FeedTrip] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return feedTrips }
        return feedTrips.filter {
            $0.trip.title.lowercased().contains(query)
            || $0.trip.destination.lowercased().contains(query)
            || $0.creatorProfile.fullName?.lowercased().contains(query) == true
            || $0.creatorProfile.handle?.lowercased().contains(query) == true
        }
    }

    // MARK: - Navigation

    var selectedCommentTripId: UUID?
    var showComments = false
    var isCloning = false

    // MARK: - Pagination

    private let pageSize = 20
    private var currentOffset = 0
    private var currentUserId: UUID?

    // MARK: - Load Feed

    func loadFeed() async {
        isLoading = feedTrips.isEmpty
        errorMessage = nil
        currentOffset = 0
        hasMore = true

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            let trips = try await TripService.fetchPublicTrips(limit: pageSize, offset: 0)
            feedTrips = try await buildFeedTrips(from: trips)
            hasMore = trips.count == pageSize
            currentOffset = trips.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        do {
            let trips = try await TripService.fetchPublicTrips(limit: pageSize, offset: currentOffset)
            let newFeedTrips = try await buildFeedTrips(from: trips)
            feedTrips.append(contentsOf: newFeedTrips)
            hasMore = trips.count == pageSize
            currentOffset += trips.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    func refreshFeed() async {
        currentOffset = 0
        hasMore = true
        feedTrips = []
        await loadFeed()
    }

    // MARK: - Like (optimistic)

    func toggleLike(_ feedTrip: FeedTrip) {
        guard let userId = currentUserId,
              let index = feedTrips.firstIndex(where: { $0.id == feedTrip.id }) else { return }

        let wasLiked = feedTrips[index].isLiked
        feedTrips[index].isLiked = !wasLiked
        feedTrips[index].likeCount += wasLiked ? -1 : 1
        HapticFeedback.light()

        Task {
            do {
                if wasLiked {
                    try await CommunityService.unlikeTrip(tripId: feedTrip.id, userId: userId)
                } else {
                    try await CommunityService.likeTrip(tripId: feedTrip.id, userId: userId)
                }
            } catch {
                // Revert on failure
                if let idx = feedTrips.firstIndex(where: { $0.id == feedTrip.id }) {
                    feedTrips[idx].isLiked = wasLiked
                    feedTrips[idx].likeCount += wasLiked ? 1 : -1
                }
            }
        }
    }

    // MARK: - Save/Bookmark (optimistic)

    func toggleSave(_ feedTrip: FeedTrip) {
        guard let userId = currentUserId,
              let index = feedTrips.firstIndex(where: { $0.id == feedTrip.id }) else { return }

        let wasSaved = feedTrips[index].isSaved
        feedTrips[index].isSaved = !wasSaved
        HapticFeedback.light()

        Task {
            do {
                if wasSaved {
                    try await CommunityService.unsaveTrip(tripId: feedTrip.id, userId: userId)
                } else {
                    try await CommunityService.saveTrip(tripId: feedTrip.id, userId: userId)
                }
            } catch {
                // Revert on failure
                if let idx = feedTrips.firstIndex(where: { $0.id == feedTrip.id }) {
                    feedTrips[idx].isSaved = wasSaved
                }
            }
        }
    }

    // MARK: - Clone Trip

    func cloneTrip(_ feedTrip: FeedTrip) async {
        guard let userId = currentUserId else { return }
        isCloning = true

        do {
            _ = try await CommunityService.cloneTrip(sourceTripId: feedTrip.id, newOwnerId: userId)
            HapticFeedback.success()
        } catch {
            errorMessage = "Failed to clone trip: \(error.localizedDescription)"
            HapticFeedback.error()
        }

        isCloning = false
    }

    // MARK: - Open Comments

    func openComments(for tripId: UUID) {
        selectedCommentTripId = tripId
        showComments = true
    }

    // MARK: - Private: Build Feed

    private func buildFeedTrips(from trips: [Trip]) async throws -> [FeedTrip] {
        guard !trips.isEmpty, let userId = currentUserId else { return [] }

        let tripIds = trips.map(\.id)
        let creatorIds = trips.map(\.createdBy)

        // Critical: creator profiles are required to render any card
        let fetchedProfiles = try await CommunityService.fetchCreatorProfiles(userIds: creatorIds)

        // Non-critical social data: fetch in parallel, default to empty on failure
        // so one failing query doesn't take down the entire feed.
        async let members = safeFetch([TripMemberPreview].self) {
            try await TripService.fetchMemberPreviews(tripIds: tripIds)
        }
        async let likes = safeFetch([UUID: Int].self) {
            try await CommunityService.fetchLikeCounts(tripIds: tripIds)
        }
        async let comments = safeFetch([UUID: Int].self) {
            try await CommunityService.fetchCommentCounts(tripIds: tripIds)
        }
        async let liked = safeFetch(Set<UUID>.self) {
            try await CommunityService.fetchLikeStatus(tripIds: tripIds, userId: userId)
        }
        async let saved = safeFetch(Set<UUID>.self) {
            try await CommunityService.fetchSaveStatus(tripIds: tripIds, userId: userId)
        }

        let fetchedMembers = await members ?? []
        let fetchedLikes = await likes ?? [:]
        let fetchedComments = await comments ?? [:]
        let fetchedLiked = await liked ?? []
        let fetchedSaved = await saved ?? []

        let profileMap = Dictionary(uniqueKeysWithValues: fetchedProfiles.map { ($0.id, $0) })
        let memberMap = Dictionary(grouping: fetchedMembers, by: \.tripId)

        return trips.compactMap { trip in
            guard let creator = profileMap[trip.createdBy] else { return nil }
            return FeedTrip(
                trip: trip,
                creatorProfile: creator,
                memberPreviews: memberMap[trip.id] ?? [],
                likeCount: fetchedLikes[trip.id] ?? 0,
                commentCount: fetchedComments[trip.id] ?? 0,
                isLiked: fetchedLiked.contains(trip.id),
                isSaved: fetchedSaved.contains(trip.id)
            )
        }
    }

    /// Runs an async throwing closure and returns nil on failure instead of propagating the error.
    private nonisolated func safeFetch<T: Sendable>(
        _ type: T.Type,
        _ block: @Sendable () async throws -> T
    ) async -> T? {
        try? await block()
    }
}
