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
    var isPrivate: Bool
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, bio, nationality, handle
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case travelInterests = "travel_interests"
        case isPrivate = "is_private"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        nationality = try container.decodeIfPresent(String.self, forKey: .nationality)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        travelInterests = try container.decodeIfPresent([String].self, forKey: .travelInterests)
        isPrivate = (try? container.decode(Bool.self, forKey: .isPrivate)) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    init(id: UUID, email: String, fullName: String? = nil, handle: String? = nil,
         avatarUrl: String? = nil, nationality: String? = nil, bio: String? = nil,
         travelInterests: [String]? = nil, isPrivate: Bool = false,
         createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id; self.email = email; self.fullName = fullName
        self.handle = handle; self.avatarUrl = avatarUrl; self.nationality = nationality
        self.bio = bio; self.travelInterests = travelInterests; self.isPrivate = isPrivate
        self.createdAt = createdAt; self.updatedAt = updatedAt
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
    var isPrivate: Bool?

    enum CodingKeys: String, CodingKey {
        case bio, nationality, handle
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case travelInterests = "travel_interests"
        case isPrivate = "is_private"
    }
}
