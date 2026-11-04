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

    /// Update a day's date in isolation (used when the user edits a single
    /// day's date or when `syncDayDatesToTrip` shifts the whole range).
    @discardableResult
    static func updateDayDate(id: UUID, date: Date?) async throws -> ItineraryDay {
        try await SupabaseManager.client
            .from("itinerary_days")
            .update(UpdateDayDatePayload(date: date))
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
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
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

    /// Re-align existing itinerary days to a (possibly new) trip date range.
    /// - No existing days: generate the full range.
    /// - Existing days: for each day, set date = startDate + (dayNumber - 1),
    ///   so day N keeps its ordinal and gets the correct new date.
    /// - New range longer than existing days: append the missing ones.
    /// - New range shorter: leave extra days in place (non-destructive — we
    ///   don't delete user activities just because the trip got shorter).
    static func syncDayDatesToTrip(
        tripId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        let existing = try await fetchDays(tripId: tripId)
        if existing.isEmpty {
            _ = try await generateDaysForTrip(
                tripId: tripId,
                startDate: startDate,
                endDate: endDate
            )
            return
        }

        for day in existing {
            guard let newDate = calendar.date(
                byAdding: .day,
                value: day.dayNumber - 1,
                to: startDay
            ) else { continue }
            if day.date != newDate {
                _ = try await updateDayDate(id: day.id, date: newDate)
            }
        }

        let totalDaysInRange = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        let maxExistingNumber = existing.map(\.dayNumber).max() ?? 0
        guard totalDaysInRange > maxExistingNumber else { return }

        var newPayloads: [CreateDayPayload] = []
        for n in (maxExistingNumber + 1)...totalDaysInRange {
            guard let date = calendar.date(byAdding: .day, value: n - 1, to: startDay) else { continue }
            newPayloads.append(CreateDayPayload(
                tripId: tripId,
                dayNumber: n,
                date: date,
                title: nil,
                notes: nil
            ))
        }
        if !newPayloads.isEmpty {
            _ = try await createDays(newPayloads)
        }
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

    /// Batch-update dayNumber and date for reordering days
    static func reorderDays(_ updates: [(id: UUID, dayNumber: Int, date: Date?)]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        for update in updates {
            let payload = UpdateDayOrderPayload(dayNumber: update.dayNumber, date: update.date)
            try await SupabaseManager.client
                .from("itinerary_days")
                .update(payload)
                .eq("id", value: update.id)
                .execute()
        }
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
