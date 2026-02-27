import Foundation

// MARK: - Trip Status

enum TripStatus: String, Codable, CaseIterable, Sendable {
    case planning
    case active
    case completed

    var label: String {
        switch self {
        case .planning: "Planning"
        case .active: "Active"
        case .completed: "Completed"
        }
    }

    var icon: String {
        switch self {
        case .planning: "pencil.and.list.clipboard"
        case .active: "airplane.departure"
        case .completed: "checkmark.circle.fill"
        }
    }
}

// MARK: - Trip

struct Trip: Codable, Identifiable, Sendable {
    let id: UUID
    let createdBy: UUID
    var title: String
    var destination: String
    var description: String?
    var coverImageUrl: String?
    var startDate: Date?
    var endDate: Date?
    var status: TripStatus
    var isPublic: Bool
    var budget: Double?
    var currency: String?
    var votingEnabled: Bool?
    var tags: [String]?
    var countryCodes: [String]?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, destination, description, status, budget, currency, tags
        case createdBy = "created_by"
        case coverImageUrl = "cover_image_url"
        case startDate = "start_date"
        case endDate = "end_date"
        case isPublic = "is_public"
        case votingEnabled = "voting_enabled"
        case countryCodes = "country_codes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Formatted date range for display (e.g. "Mar 15 – Mar 25, 2025")
    var dateRangeText: String? {
        guard let start = startDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startText = formatter.string(from: start)

        guard let end = endDate else { return startText }
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = ", yyyy"

        if Calendar.current.isDate(start, equalTo: end, toGranularity: .month) {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d"
            return "\(startText) – \(dayFormatter.string(from: end))\(yearFormatter.string(from: end))"
        }
        return "\(startText) – \(formatter.string(from: end))\(yearFormatter.string(from: end))"
    }

    /// Number of days for the trip
    var durationDays: Int? {
        guard let start = startDate, let end = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: end).day.map { $0 + 1 }
    }

    /// Days until trip starts (negative if in the past)
    var daysUntilStart: Int? {
        guard let start = startDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: start).day
    }

    /// Formatted budget for display (e.g. "$2,500.00")
    var formattedBudget: String? {
        guard let budget, budget > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: budget))
    }
}

// MARK: - Trip creation payload (only fields the user provides)

struct CreateTripPayload: Codable, Sendable {
    let createdBy: UUID
    let title: String
    let destination: String
    let description: String?
    let coverImageUrl: String?
    let startDate: Date?
    let endDate: Date?
    let status: TripStatus
    let isPublic: Bool
    let budget: Double?
    let currency: String?
    let countryCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case title, destination, description, status, budget, currency
        case createdBy = "created_by"
        case coverImageUrl = "cover_image_url"
        case startDate = "start_date"
        case endDate = "end_date"
        case isPublic = "is_public"
        case countryCodes = "country_codes"
    }
}

// MARK: - Trip update payload

struct UpdateTripPayload: Codable, Sendable {
    var title: String?
    var destination: String?
    var description: String?
    var coverImageUrl: String?
    var startDate: Date?
    var endDate: Date?
    var status: TripStatus?
    var isPublic: Bool?
    var budget: Double?
    var currency: String?
    var countryCodes: [String]?

    enum CodingKeys: String, CodingKey {
        case title, destination, description, status, budget, currency
        case coverImageUrl = "cover_image_url"
        case startDate = "start_date"
        case endDate = "end_date"
        case isPublic = "is_public"
        case countryCodes = "country_codes"
    }
}
