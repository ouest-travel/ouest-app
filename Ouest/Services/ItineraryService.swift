import Foundation
import Supabase

/// Handles all itinerary-related Supabase operations
enum ItineraryService {

    // MARK: - Days

    /// Fetch all itinerary days for a trip, with nested activities
    static func fetchDays(tripId: UUID) async throws -> [ItineraryDay] {
        try await SupabaseManager.client
            .from("itinerary_days")
            .select("*, activities:itinerary_activities(*)")
            .eq("trip_id", value: tripId)
            .order("day_number")
            .execute()
            .value
    }

    /// Create a single itinerary day
    static func createDay(_ payload: CreateDayPayload) async throws -> ItineraryDay {
        try await SupabaseManager.client
            .from("itinerary_days")
            .insert(payload)
            .select("*, activities:itinerary_activities(*)")
            .single()
            .execute()
            .value
    }

    /// Batch-create days (for auto-generation from trip date range)
    static func createDays(_ payloads: [CreateDayPayload]) async throws -> [ItineraryDay] {
        try await SupabaseManager.client
            .from("itinerary_days")
            .insert(payloads)
            .select("*, activities:itinerary_activities(*)")
            .order("day_number")
            .execute()
            .value
    }

    /// Update a day's title/notes
    static func updateDay(id: UUID, _ payload: UpdateDayPayload) async throws -> ItineraryDay {
        try await SupabaseManager.client
            .from("itinerary_days")
            .update(payload)
            .eq("id", value: id)
            .select("*, activities:itinerary_activities(*)")
            .single()
            .execute()
            .value
    }

    /// Delete a day (cascades to its activities)
    static func deleteDay(id: UUID) async throws {
        try await SupabaseManager.client
            .from("itinerary_days")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Auto-Generate Days

    /// Generate itinerary days from a trip's date range (one day per date, inclusive).
    /// Safe to call when days already exist — caller should check first.
    @discardableResult
    static func generateDaysForTrip(
        tripId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [ItineraryDay] {
        let calendar = Calendar.current
        var payloads: [CreateDayPayload] = []
        var current = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        var dayNumber = 1

        while current <= end {
            payloads.append(CreateDayPayload(
                tripId: tripId,
                dayNumber: dayNumber,
                date: current,
                title: nil,
                notes: nil
            ))
            dayNumber += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        guard !payloads.isEmpty else { return [] }
        return try await createDays(payloads)
    }

    // MARK: - Activities

    /// Create an activity
    static func createActivity(_ payload: CreateActivityPayload) async throws -> Activity {
        try await SupabaseManager.client
            .from("itinerary_activities")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update an activity
    static func updateActivity(id: UUID, _ payload: UpdateActivityPayload) async throws -> Activity {
        try await SupabaseManager.client
            .from("itinerary_activities")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    /// Delete an activity
    static func deleteActivity(id: UUID) async throws {
        try await SupabaseManager.client
            .from("itinerary_activities")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Batch-update sort_order for reordering activities within a day
    static func reorderActivities(_ updates: [(id: UUID, sortOrder: Int)]) async throws {
        for update in updates {
            try await SupabaseManager.client
                .from("itinerary_activities")
                .update(["sort_order": update.sortOrder])
                .eq("id", value: update.id)
                .execute()
        }
    }
}
