import Foundation
import Supabase

enum SupabaseManager {
    /// Custom JSON decoder that handles both PostgreSQL `timestamptz` ("2026-02-26T18:25:00+00:00")
    /// and `date` ("2026-02-26") column types. The default supabase-swift decoder only handles
    /// timestamps, causing decode failures on date-only columns like `start_date` and `end_date`.
    private static let postgrestDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds (e.g. "2026-02-26T18:25:00.706905+00:00")
            let isoFractional = ISO8601DateFormatter()
            isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFractional.date(from: string) {
                return date
            }

            // Try ISO 8601 without fractional seconds (e.g. "2026-02-26T18:25:00+00:00")
            let isoStandard = ISO8601DateFormatter()
            isoStandard.formatOptions = [.withInternetDateTime]
            if let date = isoStandard.date(from: string) {
                return date
            }

            // Try date-only format (e.g. "2026-02-26") — PostgreSQL `date` columns
            let dateOnly = DateFormatter()
            dateOnly.dateFormat = "yyyy-MM-dd"
            dateOnly.locale = Locale(identifier: "en_US_POSIX")
            dateOnly.timeZone = TimeZone(identifier: "UTC")
            if let date = dateOnly.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode date string: \(string)"
            )
        }
        return decoder
    }()

    static let client = SupabaseClient(
        supabaseURL: URL(string: Secrets.supabaseURL)!,
        supabaseKey: Secrets.supabaseAnonKey,
        options: .init(
            db: .init(decoder: postgrestDecoder)
        )
    )
}
