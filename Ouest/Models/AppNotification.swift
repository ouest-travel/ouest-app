import Foundation
import SwiftUI

// MARK: - Notification Type

enum NotificationType: String, Codable, CaseIterable, Sendable {
    case tripInvite = "trip_invite"
    case newExpense = "new_expense"
    case newComment = "new_comment"
    case tripLiked = "trip_liked"
    case newFollower = "new_follower"
    case newPoll = "new_poll"
    case newJournalEntry = "new_journal_entry"

    var label: String {
        switch self {
        case .tripInvite: "Trip Invite"
        case .newExpense: "New Expense"
        case .newComment: "New Comment"
        case .tripLiked: "Trip Liked"
        case .newFollower: "New Follower"
        case .newPoll: "New Poll"
        case .newJournalEntry: "Journal Entry"
        }
    }

    var icon: String {
        switch self {
        case .tripInvite: "person.badge.plus"
        case .newExpense: "dollarsign.circle.fill"
        case .newComment: "bubble.left.fill"
        case .tripLiked: "heart.fill"
        case .newFollower: "person.fill.checkmark"
        case .newPoll: "chart.bar.fill"
        case .newJournalEntry: "book.fill"
        }
    }

    var color: Color {
        switch self {
        case .tripInvite: .blue
        case .newExpense: .green
        case .newComment: .orange
        case .tripLiked: .pink
        case .newFollower: .purple
        case .newPoll: .orange
        case .newJournalEntry: .purple
        }
    }
}

// MARK: - App Notification

struct AppNotification: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    var type: NotificationType
    var title: String
    var body: String
    var data: [String: String]
    var isRead: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, data
        case userId = "user_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decode(NotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)

        // Data is JSONB which may decode as [String: String] or [String: Any].
        // We extract string values only.
        if let raw = try? container.decode([String: String].self, forKey: .data) {
            data = raw
        } else if let rawAny = try? container.decode([String: AnyCodable].self, forKey: .data) {
            data = rawAny.reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.stringValue
            }
        } else {
            data = [:]
        }
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        type: NotificationType,
        title: String,
        body: String,
        data: [String: String] = [:],
        isRead: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.data = data
        self.isRead = isRead
        self.createdAt = createdAt
    }

    // MARK: - Computed

    var tripId: UUID? {
        guard let str = data["trip_id"] else { return nil }
        return UUID(uuidString: str)
    }
}

// MARK: - AnyCodable Helper (for JSONB decoding)

/// Minimal wrapper that lets us decode arbitrary JSONB values and extract strings.
private struct AnyCodable: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let i = try? container.decode(Int.self) {
            stringValue = String(i)
        } else if let d = try? container.decode(Double.self) {
            stringValue = String(d)
        } else if let b = try? container.decode(Bool.self) {
            stringValue = String(b)
        } else {
            stringValue = ""
        }
    }
}

// MARK: - Device Token Payload

struct DeviceTokenPayload: Codable, Sendable {
    let userId: UUID
    let token: String
    let platform: String

    enum CodingKeys: String, CodingKey {
        case token, platform
        case userId = "user_id"
    }
}

// MARK: - Notification Preference

struct NotificationPreference: Codable, Sendable {
    let userId: UUID
    var tripInvites: Bool
    var newExpenses: Bool
    var newComments: Bool
    var tripLikes: Bool
    var newFollowers: Bool
    var newPolls: Bool
    var journalEntries: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripInvites = "trip_invites"
        case newExpenses = "new_expenses"
        case newComments = "new_comments"
        case tripLikes = "trip_likes"
        case newFollowers = "new_followers"
        case newPolls = "new_polls"
        case journalEntries = "journal_entries"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        tripInvites = try container.decodeIfPresent(Bool.self, forKey: .tripInvites) ?? true
        newExpenses = try container.decodeIfPresent(Bool.self, forKey: .newExpenses) ?? true
        newComments = try container.decodeIfPresent(Bool.self, forKey: .newComments) ?? true
        tripLikes = try container.decodeIfPresent(Bool.self, forKey: .tripLikes) ?? true
        newFollowers = try container.decodeIfPresent(Bool.self, forKey: .newFollowers) ?? true
        newPolls = try container.decodeIfPresent(Bool.self, forKey: .newPolls) ?? true
        journalEntries = try container.decodeIfPresent(Bool.self, forKey: .journalEntries) ?? true
    }

    init(
        userId: UUID,
        tripInvites: Bool = true,
        newExpenses: Bool = true,
        newComments: Bool = true,
        tripLikes: Bool = true,
        newFollowers: Bool = true,
        newPolls: Bool = true,
        journalEntries: Bool = true
    ) {
        self.userId = userId
        self.tripInvites = tripInvites
        self.newExpenses = newExpenses
        self.newComments = newComments
        self.tripLikes = tripLikes
        self.newFollowers = newFollowers
        self.newPolls = newPolls
        self.journalEntries = journalEntries
    }

    /// Returns a new preference with all defaults (everything enabled).
    static func defaults(userId: UUID) -> NotificationPreference {
        NotificationPreference(userId: userId)
    }
}

// MARK: - Push Trigger Payload (for Edge Function)

struct PushTriggerPayload: Codable, Sendable {
    let userIds: [UUID]
    let title: String
    let body: String
    let data: [String: String]

    enum CodingKeys: String, CodingKey {
        case title, body, data
        case userIds = "user_ids"
    }
}
