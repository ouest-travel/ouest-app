import Foundation
import Testing
@testable import Ouest

@Suite("Notification Models")
struct NotificationModelTests {

    // MARK: - Supabase Decoder

    private static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = isoWithFrac.date(from: str) { return d }
            if let d = isoPlain.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return decoder
    }

    // MARK: - NotificationType

    @Test("All notification types have labels")
    func typeLabels() {
        for type in NotificationType.allCases {
            #expect(!type.label.isEmpty)
        }
    }

    @Test("All notification types have icons")
    func typeIcons() {
        for type in NotificationType.allCases {
            #expect(!type.icon.isEmpty)
        }
    }

    @Test("NotificationType has exactly 7 cases")
    func typeCount() {
        #expect(NotificationType.allCases.count == 7)
    }

    @Test("NotificationType raw values match database strings")
    func typeRawValues() {
        #expect(NotificationType.tripInvite.rawValue == "trip_invite")
        #expect(NotificationType.newExpense.rawValue == "new_expense")
        #expect(NotificationType.newComment.rawValue == "new_comment")
        #expect(NotificationType.tripLiked.rawValue == "trip_liked")
        #expect(NotificationType.newFollower.rawValue == "new_follower")
        #expect(NotificationType.newPoll.rawValue == "new_poll")
        #expect(NotificationType.newJournalEntry.rawValue == "new_journal_entry")
    }

    @Test("NotificationType label values match expected")
    func typeLabelValues() {
        #expect(NotificationType.tripInvite.label == "Trip Invite")
        #expect(NotificationType.newExpense.label == "New Expense")
        #expect(NotificationType.newComment.label == "New Comment")
        #expect(NotificationType.tripLiked.label == "Trip Liked")
        #expect(NotificationType.newFollower.label == "New Follower")
        #expect(NotificationType.newPoll.label == "New Poll")
        #expect(NotificationType.newJournalEntry.label == "Journal Entry")
    }

    // MARK: - AppNotification Decoding

    @Test("Decodes a full notification from JSON")
    func decodeFullNotification() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "type": "new_expense",
            "title": "New Expense",
            "body": "Ben added Dinner",
            "data": {"trip_id": "33333333-3333-3333-3333-333333333333", "expense_id": "44444444-4444-4444-4444-444444444444"},
            "is_read": false,
            "created_at": "2025-06-01T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let notification = try Self.supabaseDecoder.decode(AppNotification.self, from: json)

        #expect(notification.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(notification.userId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(notification.type == .newExpense)
        #expect(notification.title == "New Expense")
        #expect(notification.body == "Ben added Dinner")
        #expect(notification.isRead == false)
        #expect(notification.createdAt != nil)
        #expect(notification.tripId == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(notification.data["expense_id"] == "44444444-4444-4444-4444-444444444444")
    }

    @Test("Decodes notification with minimal fields")
    func decodeMinimalNotification() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "type": "new_follower",
            "title": "New Follower",
            "body": "Alice started following you",
            "data": {}
        }
        """.data(using: .utf8)!

        let notification = try Self.supabaseDecoder.decode(AppNotification.self, from: json)

        #expect(notification.type == .newFollower)
        #expect(notification.isRead == false) // default
        #expect(notification.createdAt == nil)
        #expect(notification.tripId == nil) // no trip_id in data
        #expect(notification.data.isEmpty)
    }

    @Test("Decodes read notification")
    func decodeReadNotification() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "user_id": "22222222-2222-2222-2222-222222222222",
            "type": "trip_liked",
            "title": "Trip Liked",
            "body": "Bob liked your trip",
            "data": {"trip_id": "33333333-3333-3333-3333-333333333333"},
            "is_read": true,
            "created_at": "2025-06-01T10:00:00+00:00"
        }
        """.data(using: .utf8)!

        let notification = try Self.supabaseDecoder.decode(AppNotification.self, from: json)

        #expect(notification.isRead == true)
        #expect(notification.type == .tripLiked)
    }

    // MARK: - AppNotification Initializer

    @Test("AppNotification initializer sets all fields")
    func notificationInit() {
        let userId = UUID()
        let notification = AppNotification(
            userId: userId,
            type: .tripInvite,
            title: "Trip Invitation",
            body: "You were invited to Paris Trip",
            data: ["trip_id": UUID().uuidString],
            isRead: false
        )

        #expect(notification.userId == userId)
        #expect(notification.type == .tripInvite)
        #expect(notification.title == "Trip Invitation")
        #expect(notification.body == "You were invited to Paris Trip")
        #expect(notification.isRead == false)
        #expect(notification.tripId != nil)
    }

    @Test("AppNotification defaults: unread, empty data")
    func notificationDefaults() {
        let notification = AppNotification(
            userId: UUID(),
            type: .newComment,
            title: "Test",
            body: "Test body"
        )

        #expect(notification.isRead == false)
        #expect(notification.data.isEmpty)
        #expect(notification.tripId == nil)
        #expect(notification.createdAt == nil)
    }

    // MARK: - Notification Preference

    @Test("NotificationPreference defaults to all enabled")
    func preferenceDefaults() {
        let prefs = NotificationPreference.defaults(userId: UUID())

        #expect(prefs.tripInvites == true)
        #expect(prefs.newExpenses == true)
        #expect(prefs.newComments == true)
        #expect(prefs.tripLikes == true)
        #expect(prefs.newFollowers == true)
        #expect(prefs.newPolls == true)
        #expect(prefs.journalEntries == true)
    }

    @Test("NotificationPreference decodes from JSON")
    func decodePreference() throws {
        let json = """
        {
            "user_id": "11111111-1111-1111-1111-111111111111",
            "trip_invites": true,
            "new_expenses": false,
            "new_comments": true,
            "trip_likes": false,
            "new_followers": true,
            "new_polls": true,
            "journal_entries": false
        }
        """.data(using: .utf8)!

        let prefs = try JSONDecoder().decode(NotificationPreference.self, from: json)

        #expect(prefs.userId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(prefs.tripInvites == true)
        #expect(prefs.newExpenses == false)
        #expect(prefs.newComments == true)
        #expect(prefs.tripLikes == false)
        #expect(prefs.newFollowers == true)
        #expect(prefs.newPolls == true)
        #expect(prefs.journalEntries == false)
    }

    @Test("NotificationPreference encodes with snake_case keys")
    func encodePreference() throws {
        let prefs = NotificationPreference(
            userId: UUID(),
            tripInvites: true,
            newExpenses: false,
            newComments: true,
            tripLikes: true,
            newFollowers: false,
            newPolls: true,
            journalEntries: false
        )

        let data = try JSONEncoder().encode(prefs)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["user_id"] != nil)
        #expect(dict["trip_invites"] as? Bool == true)
        #expect(dict["new_expenses"] as? Bool == false)
        #expect(dict["new_comments"] as? Bool == true)
        #expect(dict["trip_likes"] as? Bool == true)
        #expect(dict["new_followers"] as? Bool == false)
        #expect(dict["new_polls"] as? Bool == true)
        #expect(dict["journal_entries"] as? Bool == false)

        // No camelCase keys
        #expect(dict["tripInvites"] == nil)
        #expect(dict["newExpenses"] == nil)
        #expect(dict["userId"] == nil)
    }

    // MARK: - DeviceTokenPayload

    @Test("DeviceTokenPayload encodes with snake_case keys")
    func deviceTokenPayloadEncoding() throws {
        let payload = DeviceTokenPayload(userId: UUID(), token: "abc123", platform: "ios")

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["user_id"] != nil)
        #expect(dict["token"] as? String == "abc123")
        #expect(dict["platform"] as? String == "ios")
        #expect(dict["userId"] == nil)
    }

    // MARK: - PushTriggerPayload

    @Test("PushTriggerPayload encodes with correct keys")
    func pushTriggerPayloadEncoding() throws {
        let payload = PushTriggerPayload(
            userIds: [UUID()],
            title: "Test",
            body: "Test body",
            data: ["trip_id": "abc"]
        )

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["user_ids"] != nil)
        #expect(dict["title"] as? String == "Test")
        #expect(dict["body"] as? String == "Test body")
        #expect(dict["data"] != nil)
        #expect(dict["userIds"] == nil)
    }

    // MARK: - Identifiable / Sendable

    @Test("AppNotification conforms to Identifiable with unique IDs")
    func notificationIdentifiable() {
        let n1 = AppNotification(userId: UUID(), type: .tripInvite, title: "A", body: "B")
        let n2 = AppNotification(userId: UUID(), type: .tripInvite, title: "A", body: "B")
        #expect(n1.id != n2.id)
    }
}
