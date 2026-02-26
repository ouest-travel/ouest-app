import Foundation
import SwiftUI

// MARK: - Activity Category

enum ActivityCategory: String, Codable, CaseIterable, Sendable {
    case food
    case transport
    case activity
    case accommodation
    case other

    var label: String {
        switch self {
        case .food: "Food"
        case .transport: "Transport"
        case .activity: "Activity"
        case .accommodation: "Accommodation"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .activity: "figure.walk"
        case .accommodation: "bed.double.fill"
        case .other: "mappin.and.ellipse"
        }
    }

    var color: Color {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .activity: .green
        case .accommodation: .purple
        case .other: .gray
        }
    }
}

// MARK: - Activity

struct Activity: Codable, Identifiable, Sendable {
    let id: UUID
    let dayId: UUID
    var title: String
    var description: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var startTime: String? // "HH:mm:ss" from PostgreSQL time type
    var endTime: String?   // "HH:mm:ss" from PostgreSQL time type
    var category: ActivityCategory
    var costEstimate: Double?
    var currency: String?
    var sortOrder: Int
    let createdBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, latitude, longitude, category, currency
        case dayId = "day_id"
        case locationName = "location_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case costEstimate = "cost_estimate"
        case sortOrder = "sort_order"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Memberwise init (tests + previews)

    init(
        id: UUID = UUID(), dayId: UUID, title: String, description: String? = nil,
        locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
        startTime: String? = nil, endTime: String? = nil,
        category: ActivityCategory = .other, costEstimate: Double? = nil,
        currency: String? = nil, sortOrder: Int = 0, createdBy: UUID? = nil,
        createdAt: Date? = nil, updatedAt: Date? = nil
    ) {
        self.id = id; self.dayId = dayId; self.title = title
        self.description = description; self.locationName = locationName
        self.latitude = latitude; self.longitude = longitude
        self.startTime = startTime; self.endTime = endTime
        self.category = category; self.costEstimate = costEstimate
        self.currency = currency; self.sortOrder = sortOrder
        self.createdBy = createdBy; self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    /// Formatted time range: "9:00 AM - 11:30 AM" or "9:00 AM" or nil
    var timeRangeText: String? {
        guard let start = startTime else { return nil }
        let startFormatted = formatTime(start)
        guard let end = endTime else { return startFormatted }
        return "\(startFormatted) – \(formatTime(end))"
    }

    /// Whether this activity has coordinates for map display
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    /// Formatted cost: "$25.00"
    var formattedCost: String? {
        guard let cost = costEstimate, cost > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: NSNumber(value: cost))
    }

    // MARK: - Time Formatting

    private func formatTime(_ timeString: String) -> String {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return timeString }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return timeString }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Create Activity Payload

struct CreateActivityPayload: Codable, Sendable {
    let dayId: UUID
    let title: String
    let description: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let startTime: String?
    let endTime: String?
    let category: ActivityCategory
    let costEstimate: Double?
    let currency: String?
    let sortOrder: Int
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case title, description, latitude, longitude, category, currency
        case dayId = "day_id"
        case locationName = "location_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case costEstimate = "cost_estimate"
        case sortOrder = "sort_order"
        case createdBy = "created_by"
    }
}

// MARK: - Update Activity Payload

struct UpdateActivityPayload: Codable, Sendable {
    var title: String?
    var description: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var startTime: String?
    var endTime: String?
    var category: ActivityCategory?
    var costEstimate: Double?
    var currency: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case title, description, latitude, longitude, category, currency
        case locationName = "location_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case costEstimate = "cost_estimate"
        case sortOrder = "sort_order"
    }
}
