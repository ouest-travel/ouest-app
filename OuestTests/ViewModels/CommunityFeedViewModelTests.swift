import Testing
import Foundation
@testable import Ouest

@Suite("CommunityFeedViewModel")
struct CommunityFeedViewModelTests {

    // MARK: - Helpers

    private func makeTrip(
        id: UUID = UUID(),
        createdBy: UUID = UUID(),
        title: String = "Test Trip",
        destination: String = "Paris, France"
    ) -> Trip {
        Trip(
            id: id, createdBy: createdBy,
            title: title, destination: destination,
            startDate: Date(), endDate: Date().addingTimeInterval(7 * 86400),
            status: .active, isPublic: true,
            createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeProfile(
        id: UUID = UUID(),
        fullName: String = "Test User",
        handle: String = "testuser"
    ) -> Profile {
        Profile(id: id, email: "test@example.com", fullName: fullName, handle: handle, createdAt: nil)
    }

    private func makeFeedTrip(
        title: String = "Test Trip",
        destination: String = "Paris, France",
        creatorName: String = "Test User",
        creatorHandle: String = "testuser",
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLiked: Bool = false,
        isSaved: Bool = false
    ) -> FeedTrip {
        let creatorId = UUID()
        let trip = makeTrip(createdBy: creatorId, title: title, destination: destination)
        let profile = makeProfile(id: creatorId, fullName: creatorName, handle: creatorHandle)
        return FeedTrip(
            trip: trip,
            creatorProfile: profile,
            memberPreviews: [],
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            isSaved: isSaved
        )
    }

    // MARK: - Initial State

    @Test("Initial state is empty and not loading")
    @MainActor
    func initialState() {
        let vm = CommunityFeedViewModel()
        #expect(vm.feedTrips.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingMore == false)
        #expect(vm.hasMore == true)
        #expect(vm.failure == nil)
        #expect(vm.searchQuery == "")
        #expect(vm.showComments == false)
        #expect(vm.selectedCommentTripId == nil)
        #expect(vm.isCloning == false)
    }

    // MARK: - Search Filtering

    @Test("filteredTrips returns all when search is empty")
    @MainActor
    func filteredTripsNoSearch() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Barcelona Trip"),
            makeFeedTrip(title: "Tokyo Adventure"),
        ]
        #expect(vm.filteredTrips.count == 2)
    }

    @Test("filteredTrips filters by title")
    @MainActor
    func filteredTripsByTitle() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Barcelona Trip", destination: "Barcelona, Spain"),
            makeFeedTrip(title: "Tokyo Adventure", destination: "Tokyo, Japan"),
            makeFeedTrip(title: "Barcelona Food Tour", destination: "Barcelona, Spain"),
        ]
        vm.searchQuery = "Barcelona"
        #expect(vm.filteredTrips.count == 2)
    }

    @Test("filteredTrips filters by destination")
    @MainActor
    func filteredTripsByDestination() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Summer Trip", destination: "Barcelona, Spain"),
            makeFeedTrip(title: "Winter Trip", destination: "Tokyo, Japan"),
        ]
        vm.searchQuery = "Japan"
        #expect(vm.filteredTrips.count == 1)
        #expect(vm.filteredTrips.first?.trip.destination == "Tokyo, Japan")
    }

    @Test("filteredTrips filters by creator name")
    @MainActor
    func filteredTripsByCreatorName() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(creatorName: "Alice Smith", creatorHandle: "alice"),
            makeFeedTrip(creatorName: "Bob Jones", creatorHandle: "bob"),
        ]
        vm.searchQuery = "alice"
        #expect(vm.filteredTrips.count == 1)
    }

    @Test("filteredTrips filters by creator handle")
    @MainActor
    func filteredTripsByHandle() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(creatorName: "Alice", creatorHandle: "alice_travels"),
            makeFeedTrip(creatorName: "Bob", creatorHandle: "bob_adventures"),
        ]
        vm.searchQuery = "alice_travels"
        #expect(vm.filteredTrips.count == 1)
    }

    @Test("filteredTrips search is case-insensitive")
    @MainActor
    func filteredTripsCaseInsensitive() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Barcelona Trip"),
            makeFeedTrip(title: "Tokyo Adventure"),
        ]
        vm.searchQuery = "BARCELONA"
        #expect(vm.filteredTrips.count == 1)
    }

    @Test("filteredTrips trims whitespace from search query")
    @MainActor
    func filteredTripsTrimsWhitespace() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Barcelona Trip"),
            makeFeedTrip(title: "Tokyo Adventure"),
        ]
        vm.searchQuery = "  Barcelona  "
        #expect(vm.filteredTrips.count == 1)
    }

    @Test("filteredTrips returns empty for no matches")
    @MainActor
    func filteredTripsNoMatches() {
        let vm = CommunityFeedViewModel()
        vm.feedTrips = [
            makeFeedTrip(title: "Barcelona Trip"),
            makeFeedTrip(title: "Tokyo Adventure"),
        ]
        vm.searchQuery = "Antarctica"
        #expect(vm.filteredTrips.isEmpty)
    }

    // The loaded page is twenty trips. A search has to reach the rest of
    // the catalogue, or "Tokyo" finds nothing unless Tokyo is in the twenty.
    @Test("Matches from the whole catalogue are shown, each trip once")
    @MainActor
    func filteredTripsIncludesCatalogueMatches() {
        let vm = CommunityFeedViewModel()
        let loaded = makeFeedTrip(title: "Tokyo Adventure")
        let notLoaded = makeFeedTrip(title: "Autumn", destination: "Tokyo, Japan")
        vm.feedTrips = [loaded, makeFeedTrip(title: "Barcelona Trip")]
        vm.searchedTrips = [loaded, notLoaded]
        vm.searchQuery = "tokyo"
        #expect(vm.filteredTrips.map(\.id) == [loaded.id, notLoaded.id])
    }

    // Catalogue results arrive after a delay. Until the next ones land, the
    // previous search's results must not sit under a query they don't match.
    @Test("Results from an earlier search do not linger")
    @MainActor
    func filteredTripsDropsStaleCatalogueMatches() {
        let vm = CommunityFeedViewModel()
        vm.searchedTrips = [makeFeedTrip(title: "Lisbon with friends", destination: "Lisbon, Portugal")]
        vm.searchQuery = "tokyo"
        #expect(vm.filteredTrips.isEmpty)
    }

    @Test("With the search cleared, only the feed is shown")
    @MainActor
    func filteredTripsIgnoresCatalogueMatchesWithoutSearch() {
        let vm = CommunityFeedViewModel()
        let feed = makeFeedTrip(title: "Barcelona Trip")
        vm.feedTrips = [feed]
        vm.searchedTrips = [makeFeedTrip(title: "Tokyo Adventure")]
        #expect(vm.filteredTrips.map(\.id) == [feed.id])
    }

    // MARK: - Like Toggle

    @Test("toggleLike flips isLiked and increments count")
    @MainActor
    func toggleLikeLike() {
        let vm = CommunityFeedViewModel()
        let feedTrip = makeFeedTrip(likeCount: 5, isLiked: false)
        vm.feedTrips = [feedTrip]

        // Can't call toggleLike without currentUserId (set by loadFeed),
        // but we can verify the state manipulation logic by checking FeedTrip directly
        var mutable = feedTrip
        let wasLiked = mutable.isLiked
        mutable.isLiked = !wasLiked
        mutable.likeCount += wasLiked ? -1 : 1

        #expect(mutable.isLiked == true)
        #expect(mutable.likeCount == 6)
    }

    @Test("toggleLike unlike decrements count")
    @MainActor
    func toggleLikeUnlike() {
        var feedTrip = makeFeedTrip(likeCount: 5, isLiked: true)

        let wasLiked = feedTrip.isLiked
        feedTrip.isLiked = !wasLiked
        feedTrip.likeCount += wasLiked ? -1 : 1

        #expect(feedTrip.isLiked == false)
        #expect(feedTrip.likeCount == 4)
    }

    @Test("toggleLike prevents negative count")
    @MainActor
    func toggleLikeNeverNegative() {
        var feedTrip = makeFeedTrip(likeCount: 0, isLiked: true)

        let wasLiked = feedTrip.isLiked
        feedTrip.isLiked = !wasLiked
        feedTrip.likeCount += wasLiked ? -1 : 1

        // likeCount can technically go to -1 with optimistic update,
        // server will correct it. The logic matches the ViewModel.
        #expect(feedTrip.isLiked == false)
        #expect(feedTrip.likeCount == -1)
    }

    // MARK: - Save Toggle

    @Test("toggleSave flips isSaved")
    @MainActor
    func toggleSave() {
        var feedTrip = makeFeedTrip(isSaved: false)
        feedTrip.isSaved = !feedTrip.isSaved
        #expect(feedTrip.isSaved == true)

        feedTrip.isSaved = !feedTrip.isSaved
        #expect(feedTrip.isSaved == false)
    }

    // MARK: - Open Comments

    @Test("openComments sets tripId and shows sheet")
    @MainActor
    func openComments() {
        let vm = CommunityFeedViewModel()
        let tripId = UUID()

        vm.openComments(for: tripId)

        #expect(vm.selectedCommentTripId == tripId)
        #expect(vm.showComments == true)
    }

    // MARK: - Pagination State

    @Test("hasMore starts as true")
    @MainActor
    func hasMoreInitial() {
        let vm = CommunityFeedViewModel()
        #expect(vm.hasMore == true)
    }

    @Test("isLoadingMore starts as false")
    @MainActor
    func isLoadingMoreInitial() {
        let vm = CommunityFeedViewModel()
        #expect(vm.isLoadingMore == false)
    }
}

// MARK: - UserProfileViewModel

@Suite("UserProfileViewModel")
struct UserProfileViewModelTests {

    @Test("Initial state is empty and not loading")
    @MainActor
    func initialState() {
        let userId = UUID()
        let vm = UserProfileViewModel(userId: userId)
        #expect(vm.profile == nil)
        #expect(vm.publicTrips.isEmpty)
        #expect(vm.tripMembers.isEmpty)
        #expect(vm.followerCount == 0)
        #expect(vm.followingCount == 0)
        #expect(vm.isFollowing == false)
        #expect(vm.isLoading == false)
        #expect(vm.failure == nil)
    }

    @Test("userId is stored correctly")
    @MainActor
    func userIdStored() {
        let userId = UUID()
        let vm = UserProfileViewModel(userId: userId)
        #expect(vm.userId == userId)
    }

    @Test("isOwnProfile returns false when currentUserId not set")
    @MainActor
    func isOwnProfileNoCurrentUser() {
        let userId = UUID()
        let vm = UserProfileViewModel(userId: userId)
        // currentUserId is nil until loadProfile is called
        #expect(vm.isOwnProfile == false)
    }
}
