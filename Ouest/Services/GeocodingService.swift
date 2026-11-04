import Foundation
import CoreLocation

/// Turns a free-text destination like "Paris, France" into a lat/lon via
/// Apple's `CLGeocoder`. Results are cached in-memory by the trimmed +
/// lowercased address, so opening the same trip twice in one session only
/// hits Apple's geocoder once and stays well under the ~50 req/min rate cap.
///
/// A geocode that finds no match returns `nil` — the caller uses that to hide
/// the weather section rather than surface an error to the user, because a
/// destination like "TBD" or "Home" is a legitimate app state, not a failure.
enum GeocodingService {

    struct Coordinate: Sendable, Equatable {
        let latitude: Double
        let longitude: Double
    }

    enum GeocodingError: LocalizedError {
        case emptyAddress

        var errorDescription: String? {
            switch self {
            case .emptyAddress:
                return "No destination to look up."
            }
        }
    }

    // MARK: - Cache

    private actor Cache {
        /// `nil` sentinel means "we looked and found nothing" — so the next
        /// call for the same address short-circuits without another network
        /// hit. Optional-of-Optional collapses to a single Optional in Swift,
        /// so we wrap in an enum to preserve the "miss recorded" distinction.
        enum Entry: Sendable {
            case found(Coordinate)
            case notFound
        }

        private var entries: [String: Entry] = [:]

        func get(_ key: String) -> Entry? { entries[key] }

        func set(_ entry: Entry, for key: String) { entries[key] = entry }
    }

    private static let cache = Cache()

    // MARK: - Public API

    /// Returns coordinates for the given address, or `nil` if Apple's geocoder
    /// finds no match. Throws only for unusable input (empty string) or an
    /// actual geocoder failure (network, service down).
    static func geocode(_ address: String) async throws -> Coordinate? {
        let normalized = address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { throw GeocodingError.emptyAddress }

        if let cached = await cache.get(normalized) {
            switch cached {
            case .found(let coord): return coord
            case .notFound: return nil
            }
        }

        let geocoder = CLGeocoder()
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await geocoder.geocodeAddressString(address)
        } catch let error as NSError
            where error.domain == kCLErrorDomain
            && error.code == CLError.geocodeFoundNoResult.rawValue {
            // CLGeocoder reports "no result" as a thrown error on some
            // destinations (e.g. "Test", "TBD") rather than an empty array.
            // Treat it the same as the empty-array path so the caller hides
            // the weather section instead of surfacing a scary error.
            await cache.set(.notFound, for: normalized)
            return nil
        }

        guard let location = placemarks.first?.location else {
            await cache.set(.notFound, for: normalized)
            return nil
        }

        let coord = Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        await cache.set(.found(coord), for: normalized)
        return coord
    }
}
