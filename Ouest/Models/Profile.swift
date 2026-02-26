import Foundation

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var email: String
    var fullName: String?
    var handle: String?
    var avatarUrl: String?
    var nationality: String?
    var bio: String?
    var travelInterests: [String]?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, bio, nationality, handle
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case travelInterests = "travel_interests"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Update Profile Payload

struct UpdateProfilePayload: Codable, Sendable {
    var fullName: String?
    var handle: String?
    var bio: String?
    var nationality: String?
    var avatarUrl: String?
    var travelInterests: [String]?

    enum CodingKeys: String, CodingKey {
        case bio, nationality, handle
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case travelInterests = "travel_interests"
    }
}
