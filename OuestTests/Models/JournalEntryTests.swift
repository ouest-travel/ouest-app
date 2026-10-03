import Foundation
import Testing
@testable import Ouest

@Suite("Journal Entry Models")
struct JournalEntryModelTests {

    // MARK: - JournalMood

    @Test("All mood cases have labels")
    func moodLabels() {
        for mood in JournalMood.allCases {
            #expect(!mood.label.isEmpty)
        }
    }

    @Test("All mood cases have SF Symbol icons")
    func moodIcons() {
        for mood in JournalMood.allCases {
            #expect(!mood.icon.isEmpty)
        }
    }

    @Test("Mood labels match expected values")
    func moodLabelValues() {
        #expect(JournalMood.happy.label == "Happy")
        #expect(JournalMood.excited.label == "Excited")
        #expect(JournalMood.relaxed.label == "Relaxed")
        #expect(JournalMood.nostalgic.label == "Nostalgic")
        #expect(JournalMood.adventurous.label == "Adventurous")
        #expect(JournalMood.grateful.label == "Grateful")
        #expect(JournalMood.tired.label == "Tired")
        #expect(JournalMood.reflective.label == "Reflective")
    }

    @Test("All mood cases have 8 entries")
    func moodCount() {
        #expect(JournalMood.allCases.count == 8)
    }

    @Test("Mood raw values encode as expected strings")
    func moodRawValues() {
        #expect(JournalMood.happy.rawValue == "happy")
        #expect(JournalMood.excited.rawValue == "excited")
        #expect(JournalMood.relaxed.rawValue == "relaxed")
        #expect(JournalMood.nostalgic.rawValue == "nostalgic")
        #expect(JournalMood.adventurous.rawValue == "adventurous")
        #expect(JournalMood.grateful.rawValue == "grateful")
        #expect(JournalMood.tired.rawValue == "tired")
        #expect(JournalMood.reflective.rawValue == "reflective")
    }

    // MARK: - JournalEntry Decoding

    /// Builds the same custom decoder the app uses for Supabase (supports date-only + ISO8601)
    private static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let isoWithFrac = ISO8601DateFormatter()
        isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let d = isoWithFrac.date(from: str) { return d }
            if let d = isoPlain.date(from: str) { return d }
            if let d = dateOnly.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return decoder
    }

    @Test("Decodes a full journal entry from JSON")
    func decodeFullEntry() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "entry_date": "2025-03-15",
            "title": "Eiffel Tower Visit",
            "content": "Amazing views from the top!",
            "image_url": "https://example.com/photo.jpg",
            "location_name": "Eiffel Tower, Paris",
            "latitude": 48.8584,
            "longitude": 2.2945,
            "mood": "excited",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "created_at": "2025-03-15T10:30:00+00:00",
            "updated_at": "2025-03-15T11:00:00+00:00"
        }
        """.data(using: .utf8)!

        let entry = try Self.supabaseDecoder.decode(JournalEntry.self, from: json)

        #expect(entry.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(entry.tripId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(entry.title == "Eiffel Tower Visit")
        #expect(entry.content == "Amazing views from the top!")
        #expect(entry.imageUrl == "https://example.com/photo.jpg")
        #expect(entry.locationName == "Eiffel Tower, Paris")
        #expect(entry.latitude == 48.8584)
        #expect(entry.longitude == 2.2945)
        #expect(entry.mood == .excited)
        #expect(entry.createdBy == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(entry.createdAt != nil)
        #expect(entry.updatedAt != nil)
    }

    @Test("Decodes entry with minimal fields (nullable fields omitted)")
    func decodeMinimalEntry() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "entry_date": "2025-03-15",
            "title": "Quick Note",
            "created_by": "33333333-3333-3333-3333-333333333333"
        }
        """.data(using: .utf8)!

        let entry = try Self.supabaseDecoder.decode(JournalEntry.self, from: json)

        #expect(entry.title == "Quick Note")
        #expect(entry.content == nil)
        #expect(entry.imageUrl == nil)
        #expect(entry.locationName == nil)
        #expect(entry.latitude == nil)
        #expect(entry.longitude == nil)
        #expect(entry.mood == nil)
        #expect(entry.createdAt == nil)
        #expect(entry.updatedAt == nil)
        #expect(entry.profile == nil)
    }

    @Test("Decodes mood from raw value string")
    func decodeMood() throws {
        for mood in JournalMood.allCases {
            let json = """
            "\(mood.rawValue)"
            """.data(using: .utf8)!

            let decoded = try JSONDecoder().decode(JournalMood.self, from: json)
            #expect(decoded == mood)
        }
    }

    // MARK: - JournalEntry Initialization

    @Test("JournalEntry initializer sets all fields")
    func entryInit() {
        let tripId = UUID()
        let createdBy = UUID()
        let date = Date()

        let entry = JournalEntry(
            tripId: tripId,
            entryDate: date,
            title: "Test Entry",
            content: "Some content",
            imageUrl: "https://example.com/img.jpg",
            locationName: "Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            mood: .happy,
            createdBy: createdBy
        )

        #expect(entry.tripId == tripId)
        #expect(entry.entryDate == date)
        #expect(entry.title == "Test Entry")
        #expect(entry.content == "Some content")
        #expect(entry.imageUrl == "https://example.com/img.jpg")
        #expect(entry.locationName == "Paris")
        #expect(entry.latitude == 48.8566)
        #expect(entry.longitude == 2.3522)
        #expect(entry.mood == .happy)
        #expect(entry.createdBy == createdBy)
    }

    @Test("JournalEntry defaults: id generated, date is now, optionals nil")
    func entryDefaults() {
        let entry = JournalEntry(
            tripId: UUID(),
            title: "Minimal",
            createdBy: UUID()
        )

        #expect(entry.id != UUID()) // generated unique
        #expect(entry.content == nil)
        #expect(entry.imageUrl == nil)
        #expect(entry.locationName == nil)
        #expect(entry.mood == nil)
        #expect(entry.profile == nil)
    }

    // MARK: - CreateJournalEntryPayload

    @Test("CreateJournalEntryPayload encodes with correct keys")
    func createPayloadEncoding() throws {
        let tripId = UUID()
        let userId = UUID()
        let date = Date()

        let payload = CreateJournalEntryPayload(
            tripId: tripId,
            entryDate: date,
            title: "My Entry",
            content: "Some notes",
            imageUrl: nil,
            locationName: "London",
            latitude: 51.5074,
            longitude: -0.1278,
            mood: .relaxed,
            createdBy: userId
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["trip_id"] != nil)
        #expect(dict["entry_date"] != nil)
        #expect(dict["title"] as? String == "My Entry")
        #expect(dict["content"] as? String == "Some notes")
        #expect(dict["location_name"] as? String == "London")
        #expect(dict["latitude"] as? Double == 51.5074)
        #expect(dict["longitude"] as? Double == -0.1278)
        #expect(dict["mood"] as? String == "relaxed")
        #expect(dict["created_by"] != nil)

        // Should use snake_case keys
        #expect(dict["tripId"] == nil)
        #expect(dict["entryDate"] == nil)
        #expect(dict["locationName"] == nil)
        #expect(dict["createdBy"] == nil)
    }

    // MARK: - UpdateJournalEntryPayload

    @Test("UpdateJournalEntryPayload encodes with snake_case keys")
    func updatePayloadEncoding() throws {
        let payload = UpdateJournalEntryPayload(
            entryDate: Date(),
            title: "Updated Title",
            content: "Updated content",
            imageUrl: "https://example.com/new.jpg",
            locationName: "Tokyo",
            latitude: 35.6762,
            longitude: 139.6503,
            mood: .adventurous
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["entry_date"] != nil)
        #expect(dict["title"] as? String == "Updated Title")
        #expect(dict["image_url"] as? String == "https://example.com/new.jpg")
        #expect(dict["location_name"] as? String == "Tokyo")
        #expect(dict["mood"] as? String == "adventurous")

        // Should use snake_case keys
        #expect(dict["entryDate"] == nil)
        #expect(dict["imageUrl"] == nil)
        #expect(dict["locationName"] == nil)
    }

    // MARK: - JournalEntry Identifiable / Sendable

    @Test("JournalEntry conforms to Identifiable")
    func entryIdentifiable() {
        let entry1 = JournalEntry(tripId: UUID(), title: "A", createdBy: UUID())
        let entry2 = JournalEntry(tripId: UUID(), title: "B", createdBy: UUID())
        #expect(entry1.id != entry2.id)
    }
}
