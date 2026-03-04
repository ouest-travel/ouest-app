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

            // Critical: profile + trips must succeed for the page to render
            profile = try await TripService.fetchProfile(userId: userId)
            publicTrips = try await TripService.fetchUserPublicTrips(userId: userId)

            // Non-critical social data: default to 0/false on failure
            followerCount = (try? await CommunityService.fetchFollowerCount(userId: userId)) ?? 0
            followingCount = (try? await CommunityService.fetchFollowingCount(userId: userId)) ?? 0

            if let uid = currentUserId {
                let followedSet = (try? await CommunityService.fetchFollowStatus(
                    userIds: [userId], currentUserId: uid
                )) ?? []
                isFollowing = followedSet.contains(userId)
            }

            // Non-critical: member previews for trip cards
            if !publicTrips.isEmpty {
                let tripIds = publicTrips.map(\.id)
                let members = (try? await TripService.fetchMemberPreviews(tripIds: tripIds)) ?? []
                tripMembers = Dictionary(grouping: members, by: \.tripId)
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[UserProfile] loadProfile failed: \(error)")
            #endif
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
                #if DEBUG
                print("[UserProfile] toggleFollow failed: \(error)")
                #endif
            }
        }
    }

    /// Whether this is the current user's own profile
    var isOwnProfile: Bool {
        currentUserId == userId
    }
}
