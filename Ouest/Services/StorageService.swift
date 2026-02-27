import Foundation
import Supabase

/// Handles file uploads/downloads to Supabase Storage
enum StorageService {

    /// Upload image data and return the public URL
    /// - Parameters:
    ///   - data: Raw image data (JPEG)
    ///   - bucket: Storage bucket name
    ///   - path: File path within the bucket (e.g. "userId/filename.jpg")
    /// - Returns: The public URL string for the uploaded image
    static func uploadImage(data: Data, bucket: String, path: String) async throws -> String {
        try await SupabaseManager.client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        let url = try SupabaseManager.client.storage
            .from(bucket)
            .getPublicURL(path: path)

        return url.absoluteString
    }

    /// Delete a file from storage
    static func deleteFile(bucket: String, paths: [String]) async throws {
        try await SupabaseManager.client.storage
            .from(bucket)
            .remove(paths: paths)
    }

    /// Upload a trip cover image
    /// - Parameters:
    ///   - data: JPEG image data
    ///   - userId: Current user's ID (used as folder prefix)
    ///   - tripId: Trip ID (used in filename)
    /// - Returns: Public URL for the uploaded cover image
    static func uploadTripCover(data: Data, userId: UUID, tripId: UUID) async throws -> String {
        let path = "\(userId.uuidString)/\(tripId.uuidString).jpg"
        return try await uploadImage(data: data, bucket: "trip-covers", path: path)
    }

    /// Upload a profile avatar image
    /// - Parameters:
    ///   - data: JPEG image data
    ///   - userId: Current user's ID (used as folder + filename)
    /// - Returns: Public URL for the uploaded avatar
    static func uploadProfileAvatar(data: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString)/avatar.jpg"
        return try await uploadImage(data: data, bucket: "profile-avatars", path: path)
    }

    /// Upload a journal entry photo
    /// - Parameters:
    ///   - data: JPEG image data
    ///   - tripId: Trip ID (used as folder prefix)
    ///   - entryId: Entry ID (used in filename)
    /// - Returns: Public URL for the uploaded journal photo
    static func uploadJournalPhoto(data: Data, tripId: UUID, entryId: UUID) async throws -> String {
        let path = "\(tripId.uuidString)/\(entryId.uuidString).jpg"
        return try await uploadImage(data: data, bucket: "trip-journal", path: path)
    }
}
