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
        var current = utcMidnight(sameCalendarDayAs: startDate)
        let end = utcMidnight(sameCalendarDayAs: endDate)
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
    /// - Existing days: the Nth day in dayNumber order gets startDate + (N - 1).
    ///   We walk by position, not by `dayNumber`, so legacy rows with gaps in
    ///   their numbering (1, 2, 4 …) still land on consecutive dates.
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
        let startDay = utcMidnight(sameCalendarDayAs: startDate)
        let endDay = utcMidnight(sameCalendarDayAs: endDate)

        let existing = try await fetchDays(tripId: tripId).sorted { $0.dayNumber < $1.dayNumber }
        if existing.isEmpty {
            _ = try await generateDaysForTrip(
                tripId: tripId,
                startDate: startDate,
                endDate: endDate
            )
            return
        }

        for (index, day) in existing.enumerated() {
            guard let newDate = calendar.date(
                byAdding: .day,
                value: index,
                to: startDay
            ) else { continue }
            if !isSameCalendarDay(day.date, newDate) {
                _ = try await updateDayDate(id: day.id, date: newDate)
            }
        }

        let totalDaysInRange = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        guard totalDaysInRange > existing.count else { return }

        // New rows must not collide with `UNIQUE (trip_id, day_number)`, so
        // number them past whatever the highest existing day is.
        let maxExistingNumber = existing.map(\.dayNumber).max() ?? 0
        var newPayloads: [CreateDayPayload] = []
        for offset in existing.count..<totalDaysInRange {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            newPayloads.append(CreateDayPayload(
                tripId: tripId,
                dayNumber: maxExistingNumber + 1 + (offset - existing.count),
                date: date,
                title: nil,
                notes: nil
            ))
        }
        if !newPayloads.isEmpty {
            _ = try await createDays(newPayloads)
        }
    }

    /// UTC midnight of the *local* calendar day `date` falls on. Day dates are
    /// encoded as ISO-8601 instants and Postgres keeps only the date part, so
    /// the instant has to sit at UTC midnight — local midnight east of
    /// Greenwich serialises as the previous day.
    private static func utcMidnight(sameCalendarDayAs date: Date) -> Date {
        var utc = Calendar.current
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return utc.date(from: comps) ?? utc.startOfDay(for: date)
    }

    /// Compare a decoded `date` column (local midnight) against a UTC-midnight
    /// target by calendar day, since the two represent the same day with
    /// different instants.
    private static func isSameCalendarDay(_ stored: Date?, _ target: Date) -> Bool {
        guard let stored else { return false }
        var utc = Calendar.current
        utc.timeZone = TimeZone(identifier: "UTC")!
        let a = Calendar.current.dateComponents([.year, .month, .day], from: stored)
        let b = utc.dateComponents([.year, .month, .day], from: target)
        return a == b
    }

    /// Close the `dayNumber` gap left by a deleted day so titles stay "Day 1,
    /// 2, 3" and date sync keeps mapping by position. Walks ascending so each
    /// decrement moves into a number that was just freed — no UNIQUE collision.
    static func renumberDays(after deletedNumber: Int, in days: [ItineraryDay]) async throws -> [ItineraryDay] {
        let shifted = days
            .filter { $0.dayNumber > deletedNumber }
            .sorted { $0.dayNumber < $1.dayNumber }
        var updated = days
        for day in shifted {
            let newNumber = day.dayNumber - 1
            try await SupabaseManager.client
                .from("itinerary_days")
                .update(["day_number": newNumber])
                .eq("id", value: day.id)
                .execute()
            if let i = updated.firstIndex(where: { $0.id == day.id }) {
                updated[i].dayNumber = newNumber
            }
        }
        return updated
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
