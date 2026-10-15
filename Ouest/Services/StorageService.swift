import Foundation
import Supabase
import UIKit

/// Handles file uploads/downloads to Supabase Storage
enum StorageService {

    /// Avatar upload size limit (matches profile-avatars bucket)
    private static let maxAvatarUploadSize = 2_000_000 // ~2 MB

    /// Gallery / trip cover / journal / receipt upload size limit
    /// (matches trip-gallery and similar buckets, which are 5 MB; we leave headroom)
    private static let maxGalleryUploadSize = 4_000_000 // ~4 MB

    /// Upload image data and return the public URL
    /// - Parameters:
    ///   - data: Image data (will be uploaded as-is; callers should compress first)
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

    // MARK: - Image Compression

    /// Compress and resize raw image data to fit within the given size limit.
    /// Handles HEIC, PNG, JPEG, WebP — anything `UIImage(data:)` can decode.
    /// Returns JPEG-encoded data ≤ `maxSize` bytes, or `nil` if the input can't be decoded.
    static func compressForUpload(
        _ data: Data,
        maxDimension: CGFloat = 1200,
        maxSize: Int = 2_000_000
    ) -> Data? {
        guard let original = UIImage(data: data) else { return nil }

        // Downscale if either dimension exceeds max
        let scaled: UIImage
        let size = original.size
        if size.width > maxDimension || size.height > maxDimension {
            let ratio = min(maxDimension / size.width, maxDimension / size.height)
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            scaled = renderer.image { _ in
                original.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            scaled = original
        }

        // Progressive JPEG compression — start at 0.85 quality and step down
        var quality: CGFloat = 0.85
        while quality >= 0.2 {
            if let jpeg = scaled.jpegData(compressionQuality: quality),
               jpeg.count <= maxSize {
                return jpeg
            }
            quality -= 0.1
        }

        // Last resort — lowest quality
        return scaled.jpegData(compressionQuality: 0.1)
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
        let path = "\(userId.uuidString.lowercased())/\(tripId.uuidString.lowercased()).jpg"
        return try await uploadImage(data: data, bucket: "trip-covers", path: path)
    }

    /// Upload a profile avatar image (auto-compresses to fit 2 MB limit).
    /// Appends a cache-buster query so AsyncImage reloads fresh, since avatars
    /// overwrite the same path on each update.
    /// - Parameters:
    ///   - data: Raw image data (any format from PhotosPicker)
    ///   - userId: Current user's ID (used as folder + filename)
    /// - Returns: Public URL (with cache-buster) for the uploaded avatar
    static func uploadProfileAvatar(data: Data, userId: UUID) async throws -> String {
        guard let compressed = compressForUpload(
            data,
            maxDimension: 1200,
            maxSize: maxAvatarUploadSize
        ) else {
            throw StorageError.compressionFailed
        }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        let baseURL = try await uploadImage(data: compressed, bucket: "profile-avatars", path: path)
        // Cache-buster: same path is overwritten on each avatar change, so we
        // need to force AsyncImage to fetch the new bytes.
        let bust = Int(Date().timeIntervalSince1970)
        return "\(baseURL)?v=\(bust)"
    }

    /// Delete a profile avatar from storage
    static func deleteProfileAvatar(userId: UUID) async throws {
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await deleteFile(bucket: "profile-avatars", paths: [path])
    }

    // MARK: - Errors

    enum StorageError: LocalizedError {
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "Unable to process image. Please try a different photo."
            }
        }
    }

    /// Upload a journal entry photo
    /// - Parameters:
    ///   - data: JPEG image data
    ///   - tripId: Trip ID (used as folder prefix)
    ///   - entryId: Entry ID (used in filename)
    /// - Returns: Public URL for the uploaded journal photo
    static func uploadJournalPhoto(data: Data, tripId: UUID, entryId: UUID) async throws -> String {
        let path = "\(tripId.uuidString.lowercased())/\(entryId.uuidString.lowercased()).jpg"
        return try await uploadImage(data: data, bucket: "trip-journal", path: path)
    }

    /// Upload an expense receipt photo
    /// - Parameters:
    ///   - data: JPEG image data
    ///   - tripId: Trip ID (used as folder prefix)
    ///   - expenseId: Expense ID (used in filename)
    /// - Returns: Public URL for the uploaded receipt image
    static func uploadReceipt(data: Data, tripId: UUID, expenseId: UUID) async throws -> String {
        let path = "\(tripId.uuidString.lowercased())/\(expenseId.uuidString.lowercased()).jpg"
        return try await uploadImage(data: data, bucket: "expense-receipts", path: path)
    }

    /// Upload a gallery photo for a trip.
    /// Decodes the source (HEIC/PNG/WebP/JPEG), downscales to max 2000px,
    /// and re-encodes as JPEG under 4 MB so it fits the 5 MB bucket limit
    /// with safe headroom. Source-format MIME mismatches (HEIC sent as JPEG
    /// etc.) are also resolved by this re-encoding step.
    /// - Parameters:
    ///   - data: Raw image data (any format from PhotosPicker)
    ///   - tripId: Trip ID (used as folder prefix)
    ///   - photoId: Photo ID (used in filename)
    /// - Returns: Public URL for the uploaded gallery photo
    static func uploadGalleryPhoto(data: Data, tripId: UUID, photoId: UUID) async throws -> String {
        guard let compressed = compressForUpload(
            data,
            maxDimension: 2000,
            maxSize: maxGalleryUploadSize
        ) else {
            throw StorageError.compressionFailed
        }
        let path = "\(tripId.uuidString.lowercased())/\(photoId.uuidString.lowercased()).jpg"
        return try await uploadImage(data: compressed, bucket: "trip-gallery", path: path)
    }

    /// Delete a gallery photo from storage
    static func deleteGalleryPhoto(tripId: UUID, photoId: UUID) async throws {
        let path = "\(tripId.uuidString.lowercased())/\(photoId.uuidString.lowercased()).jpg"
        try await deleteFile(bucket: "trip-gallery", paths: [path])
    }
}
