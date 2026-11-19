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

    /// Result of a multi-photo upload attempt.
    /// Allows partial successes — UI shows what made it through and reports failures separately.
    struct BatchUploadResult {
        let uploaded: [TripPhoto]
        let failures: [Error]

        var totalAttempted: Int { uploaded.count + failures.count }
        var hasFailures: Bool { !failures.isEmpty }
        var allFailed: Bool { uploaded.isEmpty && !failures.isEmpty }

        /// User-facing summary message, or nil if everything succeeded.
        var summaryMessage: String? {
            switch (uploaded.count, failures.count) {
            case (_, 0): return nil
            case (0, let f) where f == 1:
                return "1 photo couldn't be uploaded. Try again."
            case (0, let f):
                return "\(f) photos couldn't be uploaded. Try again."
            case (let u, let f):
                return "\(u) of \(u + f) photos uploaded. \(f) failed."
            }
        }
    }

    /// Upload multiple photos in parallel with partial-success handling.
    /// Failed photos don't abort the whole batch — successful ones still land.
    static func uploadPhotos(
        tripId: UUID,
        userId: UUID,
        images: [(data: Data, caption: String?)],
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async -> BatchUploadResult {
        await withTaskGroup(of: Result<TripPhoto, Error>.self) { group in
            for image in images {
                group.addTask {
                    do {
                        let photo = try await uploadPhoto(
                            tripId: tripId,
                            userId: userId,
                            imageData: image.data,
                            caption: image.caption
                        )
                        return .success(photo)
                    } catch {
                        return .failure(error)
                    }
                }
            }

            var uploaded: [TripPhoto] = []
            var failures: [Error] = []
            for await result in group {
                switch result {
                case .success(let photo): uploaded.append(photo)
                case .failure(let error): failures.append(error)
                }
                // Notify the caller after each photo finishes (in any order)
                onProgress?(uploaded.count + failures.count)
            }

            let sorted = uploaded.sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            return BatchUploadResult(uploaded: sorted, failures: failures)
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
