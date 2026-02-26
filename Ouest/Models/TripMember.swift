import Foundation

// MARK: - Member Role

enum MemberRole: String, Codable, CaseIterable, Sendable {
    case owner
    case editor
    case viewer

    var label: String {
        switch self {
        case .owner: "Owner"
        case .editor: "Editor"
        case .viewer: "Viewer"
        }
    }

    var icon: String {
        switch self {
        case .owner: "crown.fill"
        case .editor: "pencil"
        case .viewer: "eye"
        }
    }

    /// Whether this role can edit trip details
    var canEdit: Bool {
        self == .owner || self == .editor
    }
}

// MARK: - Trip Member

struct TripMember: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    var role: MemberRole
    let invitedBy: UUID?
    let joinedAt: Date?

    /// Joined profile data (populated via Supabase select with join)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, role, profile
        case tripId = "trip_id"
        case userId = "user_id"
        case invitedBy = "invited_by"
        case joinedAt = "joined_at"
    }

    // Custom decoder to handle nested `profile` from Supabase join
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        userId = try container.decode(UUID.self, forKey: .userId)
        role = try container.decode(MemberRole.self, forKey: .role)
        invitedBy = try container.decodeIfPresent(UUID.self, forKey: .invitedBy)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt)

        // Profile may come as a single object (from Supabase !inner join)
        // or may not be present at all
        if let profileData = try? container.decode(Profile.self, forKey: .profile) {
            profile = profileData
        } else {
            profile = nil
        }
    }
}

// MARK: - Lightweight member preview (for home screen trip cards)

struct MemberProfilePreview: Codable, Sendable {
    let avatarUrl: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
        case fullName = "full_name"
    }
}

struct TripMemberPreview: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let userId: UUID
    let role: MemberRole
    let profile: MemberProfilePreview?

    enum CodingKeys: String, CodingKey {
        case id, role, profile
        case tripId = "trip_id"
        case userId = "user_id"
    }
}

// MARK: - Add member payload

struct AddMemberPayload: Codable, Sendable {
    let tripId: UUID
    let userId: UUID
    let role: MemberRole
    let invitedBy: UUID

    enum CodingKeys: String, CodingKey {
        case role
        case tripId = "trip_id"
        case userId = "user_id"
        case invitedBy = "invited_by"
    }
}
