import Foundation

/// A photo uploaded to a trip's shared gallery
struct TripPhoto: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    let uploadedBy: UUID
    let imageUrl: String
    var caption: String?
    let createdAt: Date?

    /// Joined profile of the uploader (populated via Supabase select)
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case uploadedBy = "uploaded_by"
        case imageUrl = "image_url"
        case caption
        case createdAt = "created_at"
        case profile = "profiles"
    }
}

/// Payload for inserting a new gallery photo
struct CreateTripPhotoPayload: Codable, Sendable {
    let tripId: UUID
    let uploadedBy: UUID
    let imageUrl: String
    var caption: String?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case uploadedBy = "uploaded_by"
        case imageUrl = "image_url"
        case caption
    }
}
