import Foundation
import Testing
@testable import Ouest

@Suite("Poll Models")
struct PollModelTests {

    // MARK: - Supabase Decoder

    /// Builds the same custom decoder the app uses for Supabase dates.
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

    // MARK: - PollStatus

    @Test("All poll status cases have labels")
    func statusLabels() {
        for status in PollStatus.allCases {
            #expect(!status.label.isEmpty)
        }
    }

    @Test("All poll status cases have icons")
    func statusIcons() {
        for status in PollStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("PollStatus label values match expected")
    func statusLabelValues() {
        #expect(PollStatus.open.label == "Open")
        #expect(PollStatus.closed.label == "Closed")
    }

    @Test("PollStatus raw values encode correctly")
    func statusRawValues() {
        #expect(PollStatus.open.rawValue == "open")
        #expect(PollStatus.closed.rawValue == "closed")
    }

    @Test("PollStatus has exactly 2 cases")
    func statusCount() {
        #expect(PollStatus.allCases.count == 2)
    }

    // MARK: - Poll Decoding

    @Test("Decodes a full poll from JSON")
    func decodeFullPoll() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "title": "Where should we eat?",
            "description": "Pick a restaurant for Friday dinner",
            "status": "open",
            "allow_multiple": false,
            "created_by": "33333333-3333-3333-3333-333333333333",
            "created_at": "2025-06-01T10:00:00+00:00",
            "updated_at": "2025-06-01T12:00:00+00:00",
            "closed_at": null,
            "options": [],
            "profile": null
        }
        """.data(using: .utf8)!

        let poll = try Self.supabaseDecoder.decode(Poll.self, from: json)

        #expect(poll.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(poll.tripId == UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        #expect(poll.title == "Where should we eat?")
        #expect(poll.description == "Pick a restaurant for Friday dinner")
        #expect(poll.status == .open)
        #expect(poll.allowMultiple == false)
        #expect(poll.createdBy == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(poll.createdAt != nil)
        #expect(poll.updatedAt != nil)
        #expect(poll.closedAt == nil)
        #expect(poll.isOpen == true)
    }

    @Test("Decodes poll with minimal fields and defaults")
    func decodeMinimalPoll() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "title": "Quick poll",
            "created_by": "33333333-3333-3333-3333-333333333333"
        }
        """.data(using: .utf8)!

        let poll = try Self.supabaseDecoder.decode(Poll.self, from: json)

        #expect(poll.title == "Quick poll")
        #expect(poll.description == nil)
        #expect(poll.status == .open) // default
        #expect(poll.allowMultiple == false) // default
        #expect(poll.closedAt == nil)
        #expect(poll.options == nil)
        #expect(poll.profile == nil)
    }

    @Test("Decodes a closed poll")
    func decodeClosedPoll() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "title": "Closed poll",
            "status": "closed",
            "created_by": "33333333-3333-3333-3333-333333333333",
            "closed_at": "2025-06-02T18:00:00+00:00"
        }
        """.data(using: .utf8)!

        let poll = try Self.supabaseDecoder.decode(Poll.self, from: json)

        #expect(poll.status == .closed)
        #expect(poll.isOpen == false)
        #expect(poll.closedAt != nil)
    }

    // MARK: - Poll Computed Properties

    @Test("Poll.isOpen reflects status")
    func pollIsOpen() {
        let openPoll = Poll(tripId: UUID(), title: "Test", status: .open, createdBy: UUID())
        let closedPoll = Poll(tripId: UUID(), title: "Test", status: .closed, createdBy: UUID())

        #expect(openPoll.isOpen == true)
        #expect(closedPoll.isOpen == false)
    }

    @Test("Poll.totalVotes sums all option vote counts")
    func pollTotalVotes() {
        let vote1 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        let vote2 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        let vote3 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())

        let option1 = PollOption(pollId: UUID(), title: "A", votes: [vote1, vote2])
        let option2 = PollOption(pollId: UUID(), title: "B", votes: [vote3])

        let poll = Poll(tripId: UUID(), title: "Test", createdBy: UUID(), options: [option1, option2])

        #expect(poll.totalVotes == 3)
    }

    @Test("Poll.totalVotes returns 0 when no options")
    func pollTotalVotesEmpty() {
        let poll = Poll(tripId: UUID(), title: "Test", createdBy: UUID(), options: nil)
        #expect(poll.totalVotes == 0)

        let poll2 = Poll(tripId: UUID(), title: "Test", createdBy: UUID(), options: [])
        #expect(poll2.totalVotes == 0)
    }

    @Test("Poll.sortedOptions orders by sortOrder")
    func pollSortedOptions() {
        let optA = PollOption(pollId: UUID(), title: "A", sortOrder: 2)
        let optB = PollOption(pollId: UUID(), title: "B", sortOrder: 0)
        let optC = PollOption(pollId: UUID(), title: "C", sortOrder: 1)

        let poll = Poll(tripId: UUID(), title: "Test", createdBy: UUID(), options: [optA, optB, optC])

        let sorted = poll.sortedOptions
        #expect(sorted[0].title == "B")
        #expect(sorted[1].title == "C")
        #expect(sorted[2].title == "A")
    }

    // MARK: - PollOption Decoding

    @Test("Decodes a poll option from JSON")
    func decodePollOption() throws {
        let json = """
        {
            "id": "44444444-4444-4444-4444-444444444444",
            "poll_id": "11111111-1111-1111-1111-111111111111",
            "title": "Italian place",
            "sort_order": 0,
            "created_at": "2025-06-01T10:00:00+00:00",
            "votes": []
        }
        """.data(using: .utf8)!

        let option = try Self.supabaseDecoder.decode(PollOption.self, from: json)

        #expect(option.id == UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        #expect(option.pollId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(option.title == "Italian place")
        #expect(option.sortOrder == 0)
        #expect(option.createdAt != nil)
        #expect(option.voteCount == 0)
    }

    @Test("PollOption.voteCount returns correct count")
    func optionVoteCount() {
        let vote1 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        let vote2 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())

        let option = PollOption(pollId: UUID(), title: "Test", votes: [vote1, vote2])
        #expect(option.voteCount == 2)

        let emptyOption = PollOption(pollId: UUID(), title: "Test", votes: nil)
        #expect(emptyOption.voteCount == 0)
    }

    @Test("PollOption.votePercentage calculates correctly")
    func optionVotePercentage() {
        let vote = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        let option = PollOption(pollId: UUID(), title: "Test", votes: [vote])

        #expect(option.votePercentage(totalVotes: 4) == 0.25)
        #expect(option.votePercentage(totalVotes: 0) == 0)
    }

    @Test("PollOption.hasVote(by:) detects user votes")
    func optionHasVote() {
        let userId = UUID()
        let otherUserId = UUID()

        let vote = PollVote(pollId: UUID(), optionId: UUID(), userId: userId)
        let option = PollOption(pollId: UUID(), title: "Test", votes: [vote])

        #expect(option.hasVote(by: userId) == true)
        #expect(option.hasVote(by: otherUserId) == false)
    }

    @Test("PollOption.hasVote returns false when no votes")
    func optionHasVoteEmpty() {
        let option = PollOption(pollId: UUID(), title: "Test", votes: nil)
        #expect(option.hasVote(by: UUID()) == false)
    }

    // MARK: - PollVote Decoding

    @Test("Decodes a poll vote from JSON")
    func decodePollVote() throws {
        let json = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "poll_id": "11111111-1111-1111-1111-111111111111",
            "option_id": "44444444-4444-4444-4444-444444444444",
            "user_id": "33333333-3333-3333-3333-333333333333",
            "created_at": "2025-06-01T14:30:00+00:00"
        }
        """.data(using: .utf8)!

        let vote = try Self.supabaseDecoder.decode(PollVote.self, from: json)

        #expect(vote.id == UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        #expect(vote.pollId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(vote.optionId == UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        #expect(vote.userId == UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        #expect(vote.createdAt != nil)
        #expect(vote.profile == nil)
    }

    // MARK: - Poll Initializer

    @Test("Poll initializer sets all fields")
    func pollInit() {
        let tripId = UUID()
        let userId = UUID()

        let poll = Poll(
            tripId: tripId,
            title: "Where to go?",
            description: "Pick one",
            status: .open,
            allowMultiple: true,
            createdBy: userId
        )

        #expect(poll.tripId == tripId)
        #expect(poll.title == "Where to go?")
        #expect(poll.description == "Pick one")
        #expect(poll.status == .open)
        #expect(poll.allowMultiple == true)
        #expect(poll.createdBy == userId)
    }

    @Test("Poll defaults: open status, no multiple, nil optionals")
    func pollDefaults() {
        let poll = Poll(tripId: UUID(), title: "Test", createdBy: UUID())

        #expect(poll.status == .open)
        #expect(poll.allowMultiple == false)
        #expect(poll.description == nil)
        #expect(poll.closedAt == nil)
        #expect(poll.options == nil)
        #expect(poll.profile == nil)
    }

    // MARK: - Payload Encoding

    @Test("CreatePollPayload encodes with snake_case keys")
    func createPollPayloadEncoding() throws {
        let tripId = UUID()
        let userId = UUID()

        let payload = CreatePollPayload(
            tripId: tripId,
            title: "Best beach?",
            description: "Vote for your favorite",
            allowMultiple: true,
            createdBy: userId
        )

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["trip_id"] != nil)
        #expect(dict["title"] as? String == "Best beach?")
        #expect(dict["description"] as? String == "Vote for your favorite")
        #expect(dict["allow_multiple"] as? Bool == true)
        #expect(dict["created_by"] != nil)

        // Snake_case, not camelCase
        #expect(dict["tripId"] == nil)
        #expect(dict["allowMultiple"] == nil)
        #expect(dict["createdBy"] == nil)
    }

    @Test("CreatePollOptionPayload encodes with snake_case keys")
    func createPollOptionPayloadEncoding() throws {
        let pollId = UUID()

        let payload = CreatePollOptionPayload(pollId: pollId, title: "Option A", sortOrder: 0)

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["poll_id"] != nil)
        #expect(dict["title"] as? String == "Option A")
        #expect(dict["sort_order"] as? Int == 0)

        #expect(dict["pollId"] == nil)
        #expect(dict["sortOrder"] == nil)
    }

    @Test("CreatePollVotePayload encodes with snake_case keys")
    func createPollVotePayloadEncoding() throws {
        let payload = CreatePollVotePayload(pollId: UUID(), optionId: UUID(), userId: UUID())

        let data = try JSONEncoder().encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["poll_id"] != nil)
        #expect(dict["option_id"] != nil)
        #expect(dict["user_id"] != nil)

        #expect(dict["pollId"] == nil)
        #expect(dict["optionId"] == nil)
        #expect(dict["userId"] == nil)
    }

    @Test("ClosePollPayload encodes status and closed_at")
    func closePollPayloadEncoding() throws {
        let payload = ClosePollPayload(status: .closed, closedAt: Date())

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["status"] as? String == "closed")
        #expect(dict["closed_at"] != nil)
        #expect(dict["closedAt"] == nil)
    }

    // MARK: - Identifiable / Sendable

    @Test("Poll conforms to Identifiable with unique IDs")
    func pollIdentifiable() {
        let poll1 = Poll(tripId: UUID(), title: "A", createdBy: UUID())
        let poll2 = Poll(tripId: UUID(), title: "B", createdBy: UUID())
        #expect(poll1.id != poll2.id)
    }

    @Test("PollOption conforms to Identifiable with unique IDs")
    func optionIdentifiable() {
        let opt1 = PollOption(pollId: UUID(), title: "A")
        let opt2 = PollOption(pollId: UUID(), title: "B")
        #expect(opt1.id != opt2.id)
    }

    @Test("PollVote conforms to Identifiable with unique IDs")
    func voteIdentifiable() {
        let v1 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        let v2 = PollVote(pollId: UUID(), optionId: UUID(), userId: UUID())
        #expect(v1.id != v2.id)
    }

    // MARK: - Nested Decoding (Poll with Options and Votes)

    @Test("Decodes poll with nested options and votes")
    func decodeNestedPoll() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "trip_id": "22222222-2222-2222-2222-222222222222",
            "title": "Where to eat?",
            "status": "open",
            "allow_multiple": false,
            "created_by": "33333333-3333-3333-3333-333333333333",
            "created_at": "2025-06-01T10:00:00+00:00",
            "updated_at": "2025-06-01T10:00:00+00:00",
            "options": [
                {
                    "id": "44444444-4444-4444-4444-444444444444",
                    "poll_id": "11111111-1111-1111-1111-111111111111",
                    "title": "Pizza",
                    "sort_order": 0,
                    "created_at": "2025-06-01T10:00:00+00:00",
                    "votes": [
                        {
                            "id": "55555555-5555-5555-5555-555555555555",
                            "poll_id": "11111111-1111-1111-1111-111111111111",
                            "option_id": "44444444-4444-4444-4444-444444444444",
                            "user_id": "66666666-6666-6666-6666-666666666666",
                            "created_at": "2025-06-01T11:00:00+00:00"
                        }
                    ]
                },
                {
                    "id": "77777777-7777-7777-7777-777777777777",
                    "poll_id": "11111111-1111-1111-1111-111111111111",
                    "title": "Sushi",
                    "sort_order": 1,
                    "created_at": "2025-06-01T10:00:00+00:00",
                    "votes": []
                }
            ]
        }
        """.data(using: .utf8)!

        let poll = try Self.supabaseDecoder.decode(Poll.self, from: json)

        #expect(poll.options?.count == 2)
        #expect(poll.totalVotes == 1)

        let sorted = poll.sortedOptions
        #expect(sorted[0].title == "Pizza")
        #expect(sorted[0].voteCount == 1)
        #expect(sorted[0].votePercentage(totalVotes: poll.totalVotes) == 1.0)
        #expect(sorted[1].title == "Sushi")
        #expect(sorted[1].voteCount == 0)
        #expect(sorted[1].votePercentage(totalVotes: poll.totalVotes) == 0.0)
    }
}
