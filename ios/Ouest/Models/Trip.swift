import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case planning
    case upcoming
    case active
    case completed

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .upcoming: return "Upcoming"
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .planning: return "pencil.circle.fill"
        case .upcoming: return "calendar.circle.fill"
        case .active: return "airplane.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

struct Trip: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let destination: String
    let startDate: Date?
    let endDate: Date?
    let budget: Decimal?
    let currency: String
    let createdBy: String
    let isPublic: Bool
    let votingEnabled: Bool
    let coverImage: String?
    let description: String?
    let status: TripStatus
    let createdAt: Date

    // Optional joined data
    var creator: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case destination
        case startDate = "start_date"
        case endDate = "end_date"
        case budget
        case currency
        case createdBy = "created_by"
        case isPublic = "is_public"
        case votingEnabled = "voting_enabled"
        case coverImage = "cover_image"
        case description
        case status
        case createdAt = "created_at"
        case creator
    }

    // Computed properties
    var isPastTrip: Bool {
        if status == .completed { return true }
        if let endDate = endDate {
            return endDate < Date()
        }
        return false
    }

    var dateRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        guard let start = startDate else { return "Dates TBD" }

        let startStr = formatter.string(from: start)

        if let end = endDate {
            let endFormatter = DateFormatter()
            // Check if same month
            if Calendar.current.isDate(start, equalTo: end, toGranularity: .month) {
                endFormatter.dateFormat = "d, yyyy"
            } else {
                endFormatter.dateFormat = "MMM d, yyyy"
            }
            return "\(startStr) - \(endFormatter.string(from: end))"
        }

        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: start)
    }

    var destinationEmoji: String {
        // Map common destinations to emojis
        let destination = destination.lowercased()
        if destination.contains("japan") || destination.contains("tokyo") { return "🇯🇵" }
        if destination.contains("france") || destination.contains("paris") { return "🇫🇷" }
        if destination.contains("spain") || destination.contains("barcelona") { return "🇪🇸" }
        if destination.contains("italy") || destination.contains("rome") { return "🇮🇹" }
        if destination.contains("uk") || destination.contains("london") { return "🇬🇧" }
        if destination.contains("usa") || destination.contains("new york") { return "🇺🇸" }
        if destination.contains("canada") || destination.contains("toronto") { return "🇨🇦" }
        if destination.contains("australia") || destination.contains("sydney") { return "🇦🇺" }
        if destination.contains("germany") || destination.contains("berlin") { return "🇩🇪" }
        if destination.contains("thailand") || destination.contains("bangkok") { return "🇹🇭" }
        if destination.contains("mexico") { return "🇲🇽" }
        if destination.contains("brazil") { return "🇧🇷" }
        if destination.contains("korea") || destination.contains("seoul") { return "🇰🇷" }
        return "✈️"
    }
}

// MARK: - Trip Creation

struct CreateTripRequest: Codable {
    let name: String
    let destination: String
    let startDate: Date?
    let endDate: Date?
    let budget: Decimal?
    let currency: String
    let createdBy: String
    let isPublic: Bool
    let votingEnabled: Bool
    let coverImage: String?
    let description: String?
    let status: TripStatus

    enum CodingKeys: String, CodingKey {
        case name
        case destination
        case startDate = "start_date"
        case endDate = "end_date"
        case budget
        case currency
        case createdBy = "created_by"
        case isPublic = "is_public"
        case votingEnabled = "voting_enabled"
        case coverImage = "cover_image"
        case description
        case status
    }
}

struct UpdateTripRequest: Codable {
    var name: String?
    var destination: String?
    var startDate: Date?
    var endDate: Date?
    var budget: Decimal?
    var currency: String?
    var isPublic: Bool?
    var votingEnabled: Bool?
    var coverImage: String?
    var description: String?
    var status: TripStatus?

    enum CodingKeys: String, CodingKey {
        case name
        case destination
        case startDate = "start_date"
        case endDate = "end_date"
        case budget
        case currency
        case isPublic = "is_public"
        case votingEnabled = "voting_enabled"
        case coverImage = "cover_image"
        case description
        case status
    }
}
