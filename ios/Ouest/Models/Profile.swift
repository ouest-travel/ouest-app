import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let displayName: String?
    let handle: String?
    let avatarUrl: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case handle
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }

    // Computed properties
    var displayNameOrEmail: String {
        displayName ?? email.components(separatedBy: "@").first ?? email
    }

    var initials: String {
        let name = displayName ?? email
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Profile Stats

struct ProfileStats {
    let countriesVisited: Int
    let totalTrips: Int
    let memories: Int  // Count of expenses
    let savedItineraries: Int

    static let empty = ProfileStats(
        countriesVisited: 0,
        totalTrips: 0,
        memories: 0,
        savedItineraries: 0
    )

    static let demo = ProfileStats(
        countriesVisited: 5,
        totalTrips: 3,
        memories: 24,
        savedItineraries: 8
    )
}
