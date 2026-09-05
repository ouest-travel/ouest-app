import Foundation
import SwiftUI

// MARK: - Journal Mood

enum JournalMood: String, Codable, CaseIterable, Sendable {
    case happy
    case excited
    case relaxed
    case nostalgic
    case adventurous
    case grateful
    case tired
    case reflective

    var label: String {
        switch self {
        case .happy: "Happy"
        case .excited: "Excited"
        case .relaxed: "Relaxed"
        case .nostalgic: "Nostalgic"
        case .adventurous: "Adventurous"
        case .grateful: "Grateful"
        case .tired: "Tired"
        case .reflective: "Reflective"
        }
    }

    var icon: String {
        switch self {
        case .happy: "face.smiling.fill"
        case .excited: "party.popper.fill"
        case .relaxed: "leaf.fill"
        case .nostalgic: "cloud.fill"
        case .adventurous: "figure.hiking"
        case .grateful: "heart.fill"
        case .tired: "moon.zzz.fill"
        case .reflective: "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .happy: .green
        case .excited: .orange
        case .relaxed: .mint
        case .nostalgic: .indigo
        case .adventurous: .teal
        case .grateful: .pink
        case .tired: .gray
        case .reflective: .purple
        }
    }
}

// MARK: - Journal Entry

struct JournalEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    var entryDate: Date
    var title: String
    var content: String?
    var imageUrl: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var mood: JournalMood?
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?

    /// Nested profile (populated via Supabase join)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, title, content, mood, latitude, longitude, profile
        case tripId = "trip_id"
        case entryDate = "entry_date"
        case imageUrl = "image_url"
        case locationName = "location_name"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(), tripId: UUID, entryDate: Date = Date(),
        title: String, content: String? = nil, imageUrl: String? = nil,
        locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
        mood: JournalMood? = nil, createdBy: UUID,
        createdAt: Date? = nil, updatedAt: Date? = nil, profile: Profile? = nil
    ) {
        self.id = id; self.tripId = tripId; self.entryDate = entryDate
        self.title = title; self.content = content; self.imageUrl = imageUrl
        self.locationName = locationName; self.latitude = latitude; self.longitude = longitude
        self.mood = mood; self.createdBy = createdBy
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.profile = profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        entryDate = try container.decode(Date.self, forKey: .entryDate)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        mood = try container.decodeIfPresent(JournalMood.self, forKey: .mood)
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        profile = try? container.decode(Profile.self, forKey: .profile)
    }
}

// MARK: - Create Payload

struct CreateJournalEntryPayload: Codable, Sendable {
    let tripId: UUID
    let entryDate: Date
    let title: String
    let content: String?
    let imageUrl: String?
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let mood: JournalMood?
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case title, content, mood, latitude, longitude
        case tripId = "trip_id"
        case entryDate = "entry_date"
        case imageUrl = "image_url"
        case locationName = "location_name"
        case createdBy = "created_by"
    }
}

// MARK: - Update Payload

struct UpdateJournalEntryPayload: Codable, Sendable {
    var entryDate: Date?
    var title: String?
    var content: String?
    var imageUrl: String?
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var mood: JournalMood?

    enum CodingKeys: String, CodingKey {
        case title, content, mood, latitude, longitude
        case entryDate = "entry_date"
        case imageUrl = "image_url"
        case locationName = "location_name"
    }
}
