import Foundation
import Observation

/// Manages state for the journal timeline and entry creation/editing.
@MainActor @Observable
final class JournalViewModel {
    // MARK: - List State
    var entries: [JournalEntry] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Form State
    var title = ""
    var content = ""
    var entryDate = Date()
    var mood: JournalMood?
    var locationName = ""
    var imageData: Data?
    var isSaving = false

    /// Entries grouped by date for the timeline.
    var groupedEntries: [(date: Date, entries: [JournalEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.entryDate)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, entries: $0.value) }
    }

    private var currentUserId: UUID?

    // MARK: - Load

    func loadEntries(tripId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            entries = try await JournalService.fetchEntries(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create

    func createEntry(tripId: UUID) async -> JournalEntry? {
        guard let userId = currentUserId else { return nil }
        isSaving = true
        errorMessage = nil

        do {
            // Upload photo if provided
            let entryId = UUID()
            var photoUrl: String?
            if let data = imageData {
                photoUrl = try await StorageService.uploadJournalPhoto(
                    data: data, tripId: tripId, entryId: entryId
                )
            }

            let payload = CreateJournalEntryPayload(
                tripId: tripId,
                entryDate: entryDate,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
                imageUrl: photoUrl,
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: nil,
                longitude: nil,
                mood: mood,
                createdBy: userId
            )

            let entry = try await JournalService.createEntry(payload)
            entries.insert(entry, at: 0)
            entries.sort { $0.entryDate > $1.entryDate }
            resetForm()
            isSaving = false
            return entry
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    // MARK: - Update

    func updateEntry(id: UUID, tripId: UUID) async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            // Upload new photo if changed
            var photoUrl: String?
            if let data = imageData {
                photoUrl = try await StorageService.uploadJournalPhoto(
                    data: data, tripId: tripId, entryId: id
                )
            }

            var payload = UpdateJournalEntryPayload(
                entryDate: entryDate,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : content.trimmingCharacters(in: .whitespacesAndNewlines),
                locationName: locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : locationName.trimmingCharacters(in: .whitespacesAndNewlines),
                mood: mood
            )

            if let url = photoUrl {
                payload.imageUrl = url
            }

            let updated = try await JournalService.updateEntry(id: id, payload)
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index] = updated
            }
            entries.sort { $0.entryDate > $1.entryDate }
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Delete

    func deleteEntry(_ entry: JournalEntry) async {
        do {
            try await JournalService.deleteEntry(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Form Helpers

    func populateFromEntry(_ entry: JournalEntry) {
        title = entry.title
        content = entry.content ?? ""
        entryDate = entry.entryDate
        mood = entry.mood
        locationName = entry.locationName ?? ""
        imageData = nil // Don't re-upload existing images
    }

    func resetForm() {
        title = ""
        content = ""
        entryDate = Date()
        mood = nil
        locationName = ""
        imageData = nil
    }

    var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
