import Foundation
import SwiftUI

enum ItineraryCategory: String, Codable, CaseIterable {
    case food
    case activity
    case transport
    case accommodation

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .activity: return "Activity"
        case .transport: return "Transport"
        case .accommodation: return "Accommodation"
        }
    }

    var emoji: String {
        switch self {
        case .food: return "🍽️"
        case .activity: return "🎯"
        case .transport: return "🚗"
        case .accommodation: return "🏨"
        }
    }

    var color: Color {
        switch self {
        case .food: return OuestTheme.Colors.Category.food
        case .activity: return OuestTheme.Colors.Category.activities
        case .transport: return OuestTheme.Colors.Category.transport
        case .accommodation: return OuestTheme.Colors.Category.stay
        }
    }
}

struct SavedItineraryItem: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let activityName: String
    let activityLocation: String
    let activityTime: String?
    let activityCost: String?
    let activityDescription: String?
    let activityCategory: ItineraryCategory
    let sourceTripLocation: String?
    let sourceTripUser: String?
    let day: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityName = "activity_name"
        case activityLocation = "activity_location"
        case activityTime = "activity_time"
        case activityCost = "activity_cost"
        case activityDescription = "activity_description"
        case activityCategory = "activity_category"
        case sourceTripLocation = "source_trip_location"
        case sourceTripUser = "source_trip_user"
        case day
        case createdAt = "created_at"
    }
}

// MARK: - Create Saved Item Request

struct CreateSavedItineraryItemRequest: Codable {
    let userId: String
    let activityName: String
    let activityLocation: String
    let activityTime: String?
    let activityCost: String?
    let activityDescription: String?
    let activityCategory: ItineraryCategory
    let sourceTripLocation: String?
    let sourceTripUser: String?
    let day: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case activityName = "activity_name"
        case activityLocation = "activity_location"
        case activityTime = "activity_time"
        case activityCost = "activity_cost"
        case activityDescription = "activity_description"
        case activityCategory = "activity_category"
        case sourceTripLocation = "source_trip_location"
        case sourceTripUser = "source_trip_user"
        case day
    }
}
