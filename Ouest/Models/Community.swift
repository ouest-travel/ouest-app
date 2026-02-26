import Foundation
import SwiftUI

// MARK: - Travel Interest

enum TravelInterest: String, Codable, CaseIterable, Sendable {
    case beach
    case culture
    case food
    case adventure
    case nature
    case nightlife
    case history
    case photography
    case budget
    case luxury

    var label: String {
        switch self {
        case .beach: "Beach"
        case .culture: "Culture"
        case .food: "Food"
        case .adventure: "Adventure"
        case .nature: "Nature"
        case .nightlife: "Nightlife"
        case .history: "History"
        case .photography: "Photography"
        case .budget: "Budget"
        case .luxury: "Luxury"
        }
    }

    var icon: String {
        switch self {
        case .beach: "sun.max.fill"
        case .culture: "building.columns.fill"
        case .food: "fork.knife"
        case .adventure: "figure.hiking"
        case .nature: "leaf.fill"
        case .nightlife: "moon.stars.fill"
        case .history: "clock.fill"
        case .photography: "camera.fill"
        case .budget: "dollarsign.circle.fill"
        case .luxury: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .beach: .cyan
        case .culture: .purple
        case .food: .orange
        case .adventure: .green
        case .nature: .mint
        case .nightlife: .indigo
        case .history: .brown
        case .photography: .pink
        case .budget: .teal
        case .luxury: .yellow
        }
    }
}

// MARK: - Trip Like

struct TripLike: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct CreateLikePayload: Codable, Sendable {
    let tripId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case userId = "user_id"
    }
}

// MARK: - Trip Comment

struct TripComment: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date?
    var updatedAt: Date?

    /// Nested profile (populated via Supabase join)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, content, profile
        case tripId = "trip_id"
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(), tripId: UUID, userId: UUID, content: String,
        createdAt: Date? = nil, updatedAt: Date? = nil, profile: Profile? = nil
    ) {
        self.id = id; self.tripId = tripId; self.userId = userId
        self.content = content; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.profile = profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        profile = try? container.decode(Profile.self, forKey: .profile)
    }
}

struct CreateCommentPayload: Codable, Sendable {
    let tripId: UUID
    let userId: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case content
        case tripId = "trip_id"
        case userId = "user_id"
    }
}

// MARK: - Follow

struct Follow: Codable, Identifiable, Sendable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
}

struct CreateFollowPayload: Codable, Sendable {
    let followerId: UUID
    let followingId: UUID

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
    }
}

// MARK: - Saved Trip (Bookmark)

struct SavedTrip: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let tripId: UUID
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case tripId = "trip_id"
        case createdAt = "created_at"
    }
}

struct CreateSavedTripPayload: Codable, Sendable {
    let userId: UUID
    let tripId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tripId = "trip_id"
    }
}

// MARK: - Feed Trip (assembled in ViewModel, not Codable)

struct FeedTrip: Identifiable, Sendable {
    let trip: Trip
    let creatorProfile: Profile
    var memberPreviews: [TripMemberPreview]
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool

    var id: UUID { trip.id }
}

// MARK: - Like/Comment count response (for batch queries)

struct CountRow: Codable, Sendable {
    let tripId: UUID
    let count: Int

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case count
    }
}
