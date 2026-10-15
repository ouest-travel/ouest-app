import Foundation

// MARK: - Trip Invite

struct TripInvite: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let createdBy: UUID
    let code: String
    let role: MemberRole
    let expiresAt: Date?
    let maxUses: Int
    let useCount: Int
    let isActive: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, code, role
        case tripId = "trip_id"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case useCount = "use_count"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    /// The Universal Link URL for this invite.
    /// On iOS with the app installed, tapping this opens the app directly to the join screen.
    /// Without the app, it falls back to the web landing page with App Store download.
    var inviteURL: URL {
        URL(string: "https://links.ouest.travel/join/\(code)")!
    }

    /// Human-readable share text
    var shareText: String {
        "Join my trip on Ouest! \(inviteURL.absoluteString)"
    }

    /// Whether this invite is still usable
    var isValid: Bool {
        isActive
            && (expiresAt == nil || expiresAt! > Date())
            && (maxUses == 0 || useCount < maxUses)
    }
}

// MARK: - Create Invite Payload

struct CreateInvitePayload: Codable, Sendable {
    let tripId: UUID
    let createdBy: UUID
    let code: String
    let role: MemberRole
    let expiresAt: Date?
    let maxUses: Int

    enum CodingKeys: String, CodingKey {
        case code, role
        case tripId = "trip_id"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
    }
}

// MARK: - Invite Preview (from validate_invite RPC)

struct InvitePreview: Codable, Sendable {
    let tripId: UUID
    let tripTitle: String
    let tripDestination: String
    let tripCoverImageUrl: String?
    let role: String
    let creatorName: String
    let memberCount: Int
    let isAlreadyMember: Bool

    enum CodingKeys: String, CodingKey {
        case role
        case tripId = "trip_id"
        case tripTitle = "trip_title"
        case tripDestination = "trip_destination"
        case tripCoverImageUrl = "trip_cover_image_url"
        case creatorName = "creator_name"
        case memberCount = "member_count"
        case isAlreadyMember = "is_already_member"
    }
}
