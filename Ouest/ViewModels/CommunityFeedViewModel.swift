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

    var failure: OuestError?

    var failureDetail: String?

    // MARK: - Search

    var searchQuery = ""
    var searchedUsers: [Profile] = []
    var isSearchingUsers = false
    private var searchTask: Task<Void, Never>?

    /// Matches for the current search from every public trip, not only the
    /// page that happens to be loaded.
    var searchedTrips: [FeedTrip] = []
    var isSearchingTrips = false
    private var tripSearchTask: Task<Void, Never>?

    /// Loaded trips that match show at once and catalogue matches follow
    /// when they arrive. Both pass the same test, so results left from the
    /// previous keystroke drop out instead of lingering.
    var filteredTrips: [FeedTrip] {
        let query = TripService.searchTerms(searchQuery)
        guard !query.isEmpty else { return feedTrips }
        let loaded = Set(feedTrips.map(\.id))
        return (feedTrips + searchedTrips.filter { !loaded.contains($0.id) }).filter {
            $0.trip.title.lowercased().contains(query)
            || $0.trip.destination.lowercased().contains(query)
            || $0.creatorProfile.fullName?.lowercased().contains(query) == true
            || $0.creatorProfile.handle?.lowercased().contains(query) == true
        }
    }

    /// Brief error shown as a toast for interaction failures (like/save)
    var interactionError: String?

    // MARK: - Navigation

    var selectedCommentTripId: UUID?
    var showComments = false
    var isCloning = false

    // MARK: - Pagination

    private let pageSize = 20
    private var currentOffset = 0
    private var currentUserId: UUID?
    /// Authors the current user has blocked — dropped from the feed and
    /// people search client-side.
    private var blockedIds: Set<UUID> = []

    // MARK: - Load Feed

    func loadFeed() async {
        isLoading = feedTrips.isEmpty

        failure = nil

        failureDetail = nil
        currentOffset = 0
        hasMore = true

        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            currentUserId = userId
            blockedIds = (try? await ModerationService.fetchBlockedIds(for: userId)) ?? []
            let trips = try await TripService.fetchPublicTrips(limit: pageSize, offset: 0)
            feedTrips = try await buildFeedTrips(from: trips)
            hasMore = trips.count == pageSize
            currentOffset = trips.count
        } catch {

            failure = OuestError(error)

            failureDetail = error.localizedDescription
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

            failure = OuestError(error)

            failureDetail = error.localizedDescription
        }

        isLoadingMore = false
    }

    func refreshFeed() async {
        currentOffset = 0
        hasMore = true
        feedTrips = []
        await loadFeed()
        searchTrips()
    }

    // MARK: - Like (optimistic)

    func toggleLike(_ feedTrip: FeedTrip) {
        guard let userId = currentUserId else {
            #if DEBUG
            print("[CommunityFeed] toggleLike guard failed — no signed-in user")
            #endif
            return
        }

        let wasLiked = feedTrip.isLiked
        updateTrip(feedTrip.id) {
            $0.isLiked = !wasLiked
            $0.likeCount += wasLiked ? -1 : 1
        }
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
                updateTrip(feedTrip.id) {
                    $0.isLiked = wasLiked
                    $0.likeCount += wasLiked ? 1 : -1
                }
                showInteractionError("Couldn't update like")
                #if DEBUG
                print("[CommunityFeed] toggleLike failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Save/Bookmark (optimistic)

    func toggleSave(_ feedTrip: FeedTrip) {
        guard let userId = currentUserId else {
            #if DEBUG
            print("[CommunityFeed] toggleSave guard failed — no signed-in user")
            #endif
            return
        }

        let wasSaved = feedTrip.isSaved
        updateTrip(feedTrip.id) { $0.isSaved = !wasSaved }
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
                updateTrip(feedTrip.id) { $0.isSaved = wasSaved }
                showInteractionError("Couldn't save trip")
                #if DEBUG
                print("[CommunityFeed] toggleSave failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Clone Trip

    func cloneTrip(_ feedTrip: FeedTrip) async {
        guard let userId = currentUserId else { return }
        isCloning = true

        do {
            _ = try await CommunityService.cloneTrip(sourceTripId: feedTrip.id, newOwnerId: userId)
            UsageService.track(.tripCloned, tripId: feedTrip.id)
            HapticFeedback.success()
        } catch {
            HapticFeedback.error()
        }

        isCloning = false
    }

    // MARK: - Open Comments

    func openComments(for tripId: UUID) {
        selectedCommentTripId = tripId
        showComments = true
    }

    // MARK: - User Search

    func searchUsers() {
        searchTask?.cancel()

        let raw = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            searchedUsers = []
            isSearchingUsers = false
            return
        }

        // Strip leading "@" so "@mya" searches for "mya"
        let query = raw.hasPrefix("@") ? String(raw.dropFirst()) : raw
        guard !query.isEmpty else {
            searchedUsers = []
            isSearchingUsers = false
            return
        }

        isSearchingUsers = true

        searchTask = Task {
            // Debounce 300ms
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let results = try await TripService.searchProfiles(query: query)
                guard !Task.isCancelled else { return }
                // Filter out the current user and anyone they've blocked
                searchedUsers = results.filter { $0.id != currentUserId && !blockedIds.contains($0.id) }
            } catch {
                guard !Task.isCancelled else { return }
                searchedUsers = []
                #if DEBUG
                print("[CommunityFeed] searchUsers failed: \(error)")
                #endif
            }

            isSearchingUsers = false
        }
    }

    // MARK: - Trip Search

    /// Search every public trip by title or destination. The loaded page is
    /// filtered on screen straight away; this fills in the rest.
    func searchTrips() {
        tripSearchTask?.cancel()

        let query = searchQuery
        guard TripService.publicTripSearchFilter(query) != nil else {
            searchedTrips = []
            isSearchingTrips = false
            return
        }

        isSearchingTrips = true

        tripSearchTask = Task {
            // Debounce 300ms
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let trips = try await TripService.fetchPublicTrips(matching: query, limit: pageSize)
                let results = try await buildFeedTrips(from: trips)
                guard !Task.isCancelled else { return }
                searchedTrips = results
            } catch {
                guard !Task.isCancelled else { return }
                // The loaded page still filters on screen, so a failed
                // search falls back to that rather than to an error.
                #if DEBUG
                print("[CommunityFeed] searchTrips failed: \(error)")
                #endif
            }

            isSearchingTrips = false
        }
    }

    // MARK: - Private: Build Feed

    /// A trip can be on screen from the feed, from search, or both.
    private func updateTrip(_ id: UUID, _ change: (inout FeedTrip) -> Void) {
        if let index = feedTrips.firstIndex(where: { $0.id == id }) { change(&feedTrips[index]) }
        if let index = searchedTrips.firstIndex(where: { $0.id == id }) { change(&searchedTrips[index]) }
    }

    private func buildFeedTrips(from fetched: [Trip]) async throws -> [FeedTrip] {
        let trips = fetched.filter { !blockedIds.contains($0.createdBy) }
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
        do {
            return try await block()
        } catch {
            #if DEBUG
            print("[CommunityFeed] safeFetch(\(T.self)) failed: \(error)")
            #endif
            return nil
        }
    }

    private func showInteractionError(_ message: String) {
        HapticFeedback.error()
        interactionError = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if interactionError == message {
                interactionError = nil
            }
        }
    }
}
