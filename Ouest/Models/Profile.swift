import Foundation

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var email: String
    var fullName: String?
    var handle: String?
    var avatarUrl: String?
    var nationality: String?
    var bio: String?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, bio, nationality, handle
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
