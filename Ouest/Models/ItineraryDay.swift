import Foundation

// MARK: - Itinerary Day

struct ItineraryDay: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    var dayNumber: Int
    var date: Date?
    var title: String?
    var notes: String?
    let createdAt: Date?
    var updatedAt: Date?

    /// Joined activities (populated via Supabase nested select)
    var activities: [Activity]?

    enum CodingKeys: String, CodingKey {
        case id, date, title, notes, activities
        case tripId = "trip_id"
        case dayNumber = "day_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Custom Decoder (handles optional nested activities)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        date = try container.decodeIfPresent(Date.self, forKey: .date)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        activities = try? container.decode([Activity].self, forKey: .activities)
    }

    // MARK: - Memberwise Init (tests + previews)

    init(
        id: UUID = UUID(), tripId: UUID, dayNumber: Int, date: Date? = nil,
        title: String? = nil, notes: String? = nil, activities: [Activity]? = nil,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id; self.tripId = tripId; self.dayNumber = dayNumber
        self.date = date; self.title = title; self.notes = notes
        self.activities = activities; self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Display title: "Day 1 · Mar 15" or custom title or just "Day N"
    var displayTitle: String {
        let base = (title?.isEmpty == false) ? title! : "Day \(dayNumber)"
        if let date {
            return "\(base) \u{00B7} \(date.formatted_MMMd)"
        }
        return base
    }

    /// Activities sorted by sort_order
    var sortedActivities: [Activity] {
        (activities ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Total estimated cost for all activities in this day
    var totalCost: Double {
        (activities ?? []).compactMap(\.costEstimate).reduce(0, +)
    }

    /// Number of activities with map coordinates
    var activitiesWithCoordinatesCount: Int {
        (activities ?? []).filter(\.hasCoordinates).count
    }
}

// MARK: - Create Day Payload

struct CreateDayPayload: Codable, Sendable {
    let tripId: UUID
    let dayNumber: Int
    let date: Date?
    let title: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case date, title, notes
        case tripId = "trip_id"
        case dayNumber = "day_number"
    }
}

// MARK: - Update Day Payload

struct UpdateDayPayload: Codable, Sendable {
    var title: String?
    var notes: String?
}
