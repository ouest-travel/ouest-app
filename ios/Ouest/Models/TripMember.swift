import Foundation

enum MemberRole: String, Codable {
    case owner
    case member

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .member: return "Member"
        }
    }
}

struct TripMember: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    let userId: String
    let role: MemberRole
    let joinedAt: Date

    // Optional joined data
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case profile = "profiles"
    }

    static func == (lhs: TripMember, rhs: TripMember) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Trip Member Creation

struct CreateTripMemberRequest: Codable {
    let tripId: String
    let userId: String
    let role: MemberRole

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case userId = "user_id"
        case role
    }
}
