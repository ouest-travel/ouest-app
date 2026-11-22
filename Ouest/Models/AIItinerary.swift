import Foundation

// MARK: - Trip Preferences (Generate mode)

/// User-selected preferences for AI-generated itineraries.
struct TripPreferences: Codable, Sendable {
    /// Vibe tags the user picked (Adventure, Foodie, Cultural, etc.)
    var vibes: [String]

    /// Budget tier: "budget", "moderate", or "luxury"
    var budgetLevel: String?
}

// MARK: - Vibe & Budget Catalog

/// Predefined vibe options shown in the AI Generate sheet.
enum TripVibe: String, CaseIterable, Identifiable, Sendable {
    case adventure
    case relaxed
    case foodie
    case cultural
    case budget
    case nightlife
    case family
    case romantic
    case outdoors
    case shopping

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adventure:  return "Adventure"
        case .relaxed:    return "Relaxed"
        case .foodie:     return "Foodie"
        case .cultural:   return "Cultural"
        case .budget:     return "Budget"
        case .nightlife:  return "Nightlife"
        case .family:     return "Family"
        case .romantic:   return "Romantic"
        case .outdoors:   return "Outdoors"
        case .shopping:   return "Shopping"
        }
    }

    var icon: String {
        switch self {
        case .adventure: return "figure.hiking"
        case .relaxed:   return "cup.and.saucer.fill"
        case .foodie:    return "fork.knife"
        case .cultural:  return "building.columns"
        case .budget:    return "dollarsign.circle"
        case .nightlife: return "moon.stars.fill"
        case .family:    return "figure.2.and.child.holdinghands"
        case .romantic:  return "heart.fill"
        case .outdoors:  return "leaf.fill"
        case .shopping:  return "bag.fill"
        }
    }
}

/// Predefined budget level options.
enum TripBudgetLevel: String, CaseIterable, Identifiable, Sendable {
    case budget
    case moderate
    case luxury

    var id: String { rawValue }

    var label: String {
        switch self {
        case .budget:   return "Budget"
        case .moderate: return "Moderate"
        case .luxury:   return "Luxury"
        }
    }

    var subtitle: String {
        switch self {
        case .budget:   return "Hostels, street food, free attractions"
        case .moderate: return "Mid-range hotels, good restaurants"
        case .luxury:   return "Premium hotels, high-end experiences"
        }
    }
}

// MARK: - TravelInterest → AI mapping

extension TripVibe {
    /// Best-fit `TripVibe` for a `TravelInterest` raw value (from the user's profile).
    /// Returns nil when the interest only influences budget (e.g. "luxury", "budget")
    /// rather than a vibe.
    static func fromTravelInterest(_ raw: String) -> TripVibe? {
        switch raw.lowercased() {
        case "adventure":   return .adventure
        case "food":        return .foodie
        case "culture":     return .cultural
        case "history":     return .cultural    // closest fit
        case "nightlife":   return .nightlife
        case "nature":      return .outdoors
        case "beach":       return .relaxed     // beach trips skew relaxed
        case "photography": return .cultural    // closest — sightseeing-style
        // "budget" and "luxury" are handled by TripBudgetLevel.fromTravelInterests
        default: return nil
        }
    }
}

extension TripBudgetLevel {
    /// Infer a budget level from profile interests: prefer "luxury" → "budget" → moderate.
    static func fromTravelInterests(_ interests: [String]?) -> TripBudgetLevel {
        guard let interests = interests?.map({ $0.lowercased() }) else { return .moderate }
        if interests.contains("luxury") { return .luxury }
        if interests.contains("budget") { return .budget }
        return .moderate
    }
}

// MARK: - Payloads

/// Body sent to the `ai-itinerary` Edge Function for "generate" mode.
struct GenerateItineraryPayload: Codable, Sendable {
    let inputType: String = "generate"
    let tripId: UUID
    let userId: UUID
    let destination: String
    let startDate: String   // "YYYY-MM-DD"
    let endDate: String     // "YYYY-MM-DD"
    let preferences: TripPreferences
}

/// Body sent to the `ai-itinerary` Edge Function for "import" mode.
struct ImportItineraryPayload: Codable, Sendable {
    let inputType: String = "import"
    let tripId: UUID
    let userId: UUID
    let inputText: String
    let startDate: String?
    let endDate: String?
}

// MARK: - Response

/// Response returned by the `ai-itinerary` Edge Function.
struct AIItineraryResponse: Decodable, Sendable {
    let success: Bool
    let dayCount: Int?
    let activityCount: Int?
    let error: String?
}
