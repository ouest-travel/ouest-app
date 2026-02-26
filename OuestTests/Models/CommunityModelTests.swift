import Testing
import Foundation
@testable import Ouest

@Suite("Community Models")
struct CommunityModelTests {

    // MARK: - TravelInterest

    @Test("All travel interests have non-empty labels and icons")
    func travelInterestProperties() {
        for interest in TravelInterest.allCases {
            #expect(!interest.label.isEmpty)
            #expect(!interest.icon.isEmpty)
        }
    }

    @Test("Travel interest count is 10")
    func travelInterestCount() {
        #expect(TravelInterest.allCases.count == 10)
    }

    @Test("Travel interest raw values match database values")
    func travelInterestRawValues() {
        #expect(TravelInterest.beach.rawValue == "beach")
        #expect(TravelInterest.culture.rawValue == "culture")
        #expect(TravelInterest.food.rawValue == "food")
        #expect(TravelInterest.adventure.rawValue == "adventure")
        #expect(TravelInterest.nature.rawValue == "nature")
        #expect(TravelInterest.nightlife.rawValue == "nightlife")
        #expect(TravelInterest.history.rawValue == "history")
        #expect(TravelInterest.photography.rawValue == "photography")
        #expect(TravelInterest.budget.rawValue == "budget")
        #expect(TravelInterest.luxury.rawValue == "luxury")
    }

    @Test("Travel interests decode from raw values")
    func travelInterestDecode() {
        for interest in TravelInterest.allCases {
            let decoded = TravelInterest(rawValue: interest.rawValue)
            #expect(decoded == interest)
        }
    }

    // MARK: - TripLike

    @Test("TripLike stores correct properties")
    func tripLikeProperties() {
        let tripId = UUID()
        let userId = UUID()
        let like = TripLike(id: UUID(), tripId: tripId, userId: userId, createdAt: Date())
        #expect(like.tripId == tripId)
        #expect(like.userId == userId)
    }

    // MARK: - TripComment

    @Test("TripComment memberwise init works")
    func tripCommentInit() {
        let tripId = UUID()
        let userId = UUID()
        let comment = TripComment(
            tripId: tripId, userId: userId, content: "Great trip!",
            createdAt: Date(), profile: nil
        )
        #expect(comment.tripId == tripId)
        #expect(comment.userId == userId)
        #expect(comment.content == "Great trip!")
        #expect(comment.profile == nil)
    }

    @Test("TripComment init with nested profile")
    func tripCommentWithProfile() {
        let profile = Profile(id: UUID(), email: "a@b.com", fullName: "Alice", createdAt: nil)
        let comment = TripComment(
            tripId: UUID(), userId: profile.id, content: "Hello",
            profile: profile
        )
        #expect(comment.profile?.fullName == "Alice")
    }

    // MARK: - Follow

    @Test("Follow stores follower and following IDs")
    func followProperties() {
        let followerId = UUID()
        let followingId = UUID()
        let follow = Follow(id: UUID(), followerId: followerId, followingId: followingId, createdAt: Date())
        #expect(follow.followerId == followerId)
        #expect(follow.followingId == followingId)
    }

    // MARK: - SavedTrip

    @Test("SavedTrip stores user and trip IDs")
    func savedTripProperties() {
        let userId = UUID()
        let tripId = UUID()
        let saved = SavedTrip(id: UUID(), userId: userId, tripId: tripId, createdAt: Date())
        #expect(saved.userId == userId)
        #expect(saved.tripId == tripId)
    }

    // MARK: - FeedTrip

    @Test("FeedTrip id comes from trip")
    func feedTripId() {
        let trip = Trip(
            id: UUID(), createdBy: UUID(),
            title: "Test", destination: "Paris",
            startDate: nil, endDate: nil,
            status: .active, isPublic: true,
            createdAt: Date(), updatedAt: Date()
        )
        let feedTrip = FeedTrip(
            trip: trip,
            creatorProfile: Profile(id: trip.createdBy, email: "a@b.com", createdAt: nil),
            memberPreviews: [],
            likeCount: 5,
            commentCount: 3,
            isLiked: true,
            isSaved: false
        )
        #expect(feedTrip.id == trip.id)
        #expect(feedTrip.likeCount == 5)
        #expect(feedTrip.commentCount == 3)
        #expect(feedTrip.isLiked == true)
        #expect(feedTrip.isSaved == false)
    }

    @Test("FeedTrip mutability for optimistic updates")
    func feedTripMutable() {
        let trip = Trip(
            id: UUID(), createdBy: UUID(),
            title: "Mutate Test", destination: "London",
            startDate: nil, endDate: nil,
            status: .active, isPublic: true,
            createdAt: Date(), updatedAt: Date()
        )
        var feedTrip = FeedTrip(
            trip: trip,
            creatorProfile: Profile(id: trip.createdBy, email: "a@b.com", createdAt: nil),
            memberPreviews: [],
            likeCount: 10,
            commentCount: 2,
            isLiked: false,
            isSaved: false
        )

        // Simulate optimistic like
        feedTrip.isLiked = true
        feedTrip.likeCount += 1
        #expect(feedTrip.isLiked == true)
        #expect(feedTrip.likeCount == 11)

        // Simulate optimistic save
        feedTrip.isSaved = true
        #expect(feedTrip.isSaved == true)
    }

    // MARK: - Payloads

    @Test("CreateLikePayload encodes with snake_case keys")
    func likePayloadEncodes() throws {
        let payload = CreateLikePayload(tripId: UUID(), userId: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["trip_id"] != nil)
        #expect(json?["user_id"] != nil)
    }

    @Test("CreateCommentPayload encodes with correct keys")
    func commentPayloadEncodes() throws {
        let payload = CreateCommentPayload(tripId: UUID(), userId: UUID(), content: "Nice trip!")
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["trip_id"] != nil)
        #expect(json?["user_id"] != nil)
        #expect(json?["content"] as? String == "Nice trip!")
    }

    @Test("CreateFollowPayload encodes with correct keys")
    func followPayloadEncodes() throws {
        let followerId = UUID()
        let followingId = UUID()
        let payload = CreateFollowPayload(followerId: followerId, followingId: followingId)
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["follower_id"] != nil)
        #expect(json?["following_id"] != nil)
    }

    @Test("CreateSavedTripPayload encodes with correct keys")
    func savedTripPayloadEncodes() throws {
        let payload = CreateSavedTripPayload(userId: UUID(), tripId: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["user_id"] != nil)
        #expect(json?["trip_id"] != nil)
    }

    // MARK: - CountRow

    @Test("CountRow decodes trip_id and count")
    func countRowDecode() throws {
        let tripId = UUID()
        let json = """
        {"trip_id": "\(tripId.uuidString)", "count": 42}
        """
        let decoder = JSONDecoder()
        let row = try decoder.decode(CountRow.self, from: Data(json.utf8))
        #expect(row.tripId == tripId)
        #expect(row.count == 42)
    }

    // MARK: - Date+Relative

    @Test("Date.relativeText shows 'Just now' for recent dates")
    func relativeTextJustNow() {
        let now = Date()
        #expect(now.relativeText == "Just now")

        let tenSecondsAgo = Date(timeIntervalSinceNow: -10)
        #expect(tenSecondsAgo.relativeText == "Just now")
    }

    @Test("Date.relativeText shows minutes")
    func relativeTextMinutes() {
        let fiveMinutesAgo = Date(timeIntervalSinceNow: -5 * 60)
        #expect(fiveMinutesAgo.relativeText == "5m")

        let thirtyMinutesAgo = Date(timeIntervalSinceNow: -30 * 60)
        #expect(thirtyMinutesAgo.relativeText == "30m")
    }

    @Test("Date.relativeText shows hours")
    func relativeTextHours() {
        let twoHoursAgo = Date(timeIntervalSinceNow: -2 * 3600)
        #expect(twoHoursAgo.relativeText == "2h")

        let twentyThreeHoursAgo = Date(timeIntervalSinceNow: -23 * 3600)
        #expect(twentyThreeHoursAgo.relativeText == "23h")
    }

    @Test("Date.relativeText shows days")
    func relativeTextDays() {
        let threeDaysAgo = Date(timeIntervalSinceNow: -3 * 86400)
        #expect(threeDaysAgo.relativeText == "3d")

        let sixDaysAgo = Date(timeIntervalSinceNow: -6 * 86400)
        #expect(sixDaysAgo.relativeText == "6d")
    }

    @Test("Date.relativeText shows weeks")
    func relativeTextWeeks() {
        let twoWeeksAgo = Date(timeIntervalSinceNow: -14 * 86400)
        #expect(twoWeeksAgo.relativeText == "2w")

        let threeWeeksAgo = Date(timeIntervalSinceNow: -21 * 86400)
        #expect(threeWeeksAgo.relativeText == "3w")
    }

    @Test("Date.relativeText shows date for old entries")
    func relativeTextOld() {
        let twoMonthsAgo = Date(timeIntervalSinceNow: -60 * 86400)
        let text = twoMonthsAgo.relativeText
        // Should be a formatted date like "Dec 28" or "Dec 28, 2025"
        #expect(!text.hasSuffix("d"))
        #expect(!text.hasSuffix("w"))
        #expect(!text.hasSuffix("m"))
        #expect(!text.hasSuffix("h"))
        #expect(text != "Just now")
    }

    @Test("Date.relativeText handles future dates as 'Just now'")
    func relativeTextFuture() {
        let future = Date(timeIntervalSinceNow: 3600)
        #expect(future.relativeText == "Just now")
    }
}
