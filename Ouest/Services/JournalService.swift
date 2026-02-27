import Foundation

// MARK: - Journal Service

enum JournalService {

    /// Fetch all journal entries for a trip, ordered by date descending.
    static func fetchEntries(tripId: UUID) async throws -> [JournalEntry] {
        try await SupabaseManager.client
            .from("journal_entries")
            .select("*, profile:profiles!journal_entries_created_by_fkey(*)")
            .eq("trip_id", value: tripId)
            .order("entry_date", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Create a new journal entry.
    static func createEntry(_ payload: CreateJournalEntryPayload) async throws -> JournalEntry {
        try await SupabaseManager.client
            .from("journal_entries")
            .insert(payload)
            .select("*, profile:profiles!journal_entries_created_by_fkey(*)")
            .single()
            .execute()
            .value
    }

    /// Update an existing journal entry.
    static func updateEntry(id: UUID, _ payload: UpdateJournalEntryPayload) async throws -> JournalEntry {
        try await SupabaseManager.client
            .from("journal_entries")
            .update(payload)
            .eq("id", value: id)
            .select("*, profile:profiles!journal_entries_created_by_fkey(*)")
            .single()
            .execute()
            .value
    }

    /// Delete a journal entry.
    static func deleteEntry(id: UUID) async throws {
        try await SupabaseManager.client
            .from("journal_entries")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
