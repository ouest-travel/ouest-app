import Foundation
import Supabase

/// Wraps the `ai-itinerary` Supabase Edge Function for AI-driven itinerary creation.
///
/// Two modes:
///   - `generate(...)` — given destination/dates/preferences, ask Claude for a full itinerary
///   - `import(...)`   — given a URL, blog post, or freeform description, extract an itinerary
///
/// The Edge Function inserts days and activities directly using the service role key,
/// so the caller doesn't need to do any extra DB writes — just refetch after the call returns.
enum AIItineraryService {

    // MARK: - Generate

    @discardableResult
    static func generateItinerary(
        tripId: UUID,
        userId: UUID,
        destination: String,
        startDate: Date,
        endDate: Date,
        preferences: TripPreferences
    ) async throws -> AIItineraryResponse {
        let payload = GenerateItineraryPayload(
            tripId: tripId,
            userId: userId,
            destination: destination,
            startDate: Self.isoDate(startDate),
            endDate: Self.isoDate(endDate),
            preferences: preferences
        )
        return try await invoke(payload: payload)
    }

    // MARK: - Import

    @discardableResult
    static func importItinerary(
        tripId: UUID,
        userId: UUID,
        inputText: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> AIItineraryResponse {
        let payload = ImportItineraryPayload(
            tripId: tripId,
            userId: userId,
            inputText: inputText,
            startDate: startDate.map { Self.isoDate($0) },
            endDate: endDate.map { Self.isoDate($0) }
        )
        return try await invoke(payload: payload)
    }

    // MARK: - Invoke

    /// Invokes the Edge Function and decodes the JSON response.
    /// The function may return a 200 with `success: false` for app-level errors — we surface those as thrown errors.
    private static func invoke<P: Encodable>(payload: P) async throws -> AIItineraryResponse {
        let response: AIItineraryResponse = try await SupabaseManager.client.functions.invoke(
            "ai-itinerary",
            options: .init(body: payload)
        )

        if !response.success {
            throw AIItineraryError.failed(message: response.error ?? "Unknown error from AI service.")
        }

        return response
    }

    // MARK: - Helpers

    /// Encode a Date as ISO "YYYY-MM-DD" in UTC (matches the Edge Function's expected format).
    private static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}

// MARK: - Errors

enum AIItineraryError: LocalizedError {
    case failed(message: String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        }
    }
}
