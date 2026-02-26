import Foundation
import Observation

/// Manages another user's profile view (public trips, follow state)
@MainActor @Observable
final class UserProfileViewModel {

    // MARK: - State

    var profile: Profile?
    var publicTrips: [Trip] = []
    var tripMembers: [UUID: [TripMemberPreview]] = [:]
    var followerCount = 0
    var followingCount = 0
    var isFollowing = false
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private var currentUserId: UUID?
    let userId: UUID

    init(userId: UUID) {
        self.userId = userId
    }

    // MARK: - Load

    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id

            // Fetch everything in parallel
            async let fetchedProfile = TripService.fetchProfile(userId: userId)
            async let fetchedTrips = TripService.fetchUserPublicTrips(userId: userId)
            async let fetchedFollowers = CommunityService.fetchFollowerCount(userId: userId)
            async let fetchedFollowing = CommunityService.fetchFollowingCount(userId: userId)
            async let followStatus = CommunityService.fetchFollowStatus(
                userIds: [userId], currentUserId: currentUserId!
            )

            profile = try await fetchedProfile
            publicTrips = try await fetchedTrips
            followerCount = try await fetchedFollowers
            followingCount = try await fetchedFollowing
            isFollowing = try await followStatus.contains(userId)

            // Fetch member previews for the trips
            if !publicTrips.isEmpty {
                let tripIds = publicTrips.map(\.id)
                let members = try await TripService.fetchMemberPreviews(tripIds: tripIds)
                tripMembers = Dictionary(grouping: members, by: \.tripId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Follow / Unfollow

    func toggleFollow() {
        guard let currentUserId else { return }
        guard userId != currentUserId else { return } // Can't follow yourself

        let wasFollowing = isFollowing
        isFollowing = !wasFollowing
        followerCount += wasFollowing ? -1 : 1
        HapticFeedback.light()

        Task {
            do {
                if wasFollowing {
                    try await CommunityService.unfollowUser(followingId: userId, followerId: currentUserId)
                } else {
                    try await CommunityService.followUser(followingId: userId, followerId: currentUserId)
                }
            } catch {
                // Revert on failure
                isFollowing = wasFollowing
                followerCount += wasFollowing ? 1 : -1
            }
        }
    }

    /// Whether this is the current user's own profile
    var isOwnProfile: Bool {
        currentUserId == userId
    }
}
