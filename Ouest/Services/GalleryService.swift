import Foundation

/// Handles trip photo gallery operations with Supabase
enum GalleryService {

    /// Fetch all photos for a trip, newest first, with uploader profiles
    static func fetchPhotos(tripId: UUID) async throws -> [TripPhoto] {
        try await SupabaseManager.client
            .from("trip_photos")
            .select("*, profiles!trip_photos_uploaded_by_fkey(*)")
            .eq("trip_id", value: tripId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Upload a single photo to the gallery
    /// - Returns: The created TripPhoto with profile data
    static func uploadPhoto(
        tripId: UUID,
        userId: UUID,
        imageData: Data,
        caption: String? = nil
    ) async throws -> TripPhoto {
        let photoId = UUID()

        // 1. Upload image to storage
        let imageUrl = try await StorageService.uploadGalleryPhoto(
            data: imageData,
            tripId: tripId,
            photoId: photoId
        )

        // 2. Insert record into database
        let payload = CreateTripPhotoPayload(
            tripId: tripId,
            uploadedBy: userId,
            imageUrl: imageUrl,
            caption: caption
        )

        let photo: TripPhoto = try await SupabaseManager.client
            .from("trip_photos")
            .insert(payload)
            .select("*, profiles!trip_photos_uploaded_by_fkey(*)")
            .single()
            .execute()
            .value

        return photo
    }

    /// Upload multiple photos in parallel
    /// - Returns: Array of created TripPhotos
    static func uploadPhotos(
        tripId: UUID,
        userId: UUID,
        images: [(data: Data, caption: String?)]
    ) async throws -> [TripPhoto] {
        try await withThrowingTaskGroup(of: TripPhoto.self) { group in
            for image in images {
                group.addTask {
                    try await uploadPhoto(
                        tripId: tripId,
                        userId: userId,
                        imageData: image.data,
                        caption: image.caption
                    )
                }
            }

            var photos: [TripPhoto] = []
            for try await photo in group {
                photos.append(photo)
            }
            return photos.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
    }

    /// Delete a photo from both the database and storage
    static func deletePhoto(_ photo: TripPhoto) async throws {
        // 1. Delete from database
        try await SupabaseManager.client
            .from("trip_photos")
            .delete()
            .eq("id", value: photo.id)
            .execute()

        // 2. Delete from storage
        try? await StorageService.deleteGalleryPhoto(
            tripId: photo.tripId,
            photoId: photo.id
        )
    }
}
