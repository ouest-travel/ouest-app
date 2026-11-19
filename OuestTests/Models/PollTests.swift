import Foundation
import Testing
@testable import Ouest

@Suite("Poll Models")
struct PollModelTests {

    // MARK: - Supabase Decoder

    /// Builds the same custom decoder the app uses for Supabase dates.
    private static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let isoWithFrac = ISO8601DateFormatter()
            isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoPlain = ISO8601DateFormatter()
            isoPlain.formatOptions = [.withInternetDateTime]
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

    // MARK: - Deadlines

    // The database marks a poll closed on a schedule, a minute or more
    // behind the clock. The group was told a time, so voting has to stop at
    // that time, not whenever the status catches up.
    @Test("Voting stops at the deadline even while the status still says open")
    func deadlineClosesVoting() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let poll = Poll(tripId: UUID(), title: "Dinner tonight", status: .open, createdBy: UUID(), closesAt: deadline)

        #expect(poll.isOpen(at: deadline.addingTimeInterval(-1)) == true)
        #expect(poll.isOpen(at: deadline) == false)
        #expect(poll.isOpen(at: deadline.addingTimeInterval(3_600)) == false)
    }

    // A deadline is optional. Polls made before deadlines existed have none
    // and must not close by themselves.
    @Test("A poll with no deadline stays open until someone closes it")
    func noDeadlineStaysOpen() {
        let poll = Poll(tripId: UUID(), title: "Which month?", status: .open, createdBy: UUID())
        #expect(poll.isOpen(at: .distantFuture) == true)
    }

    // The lead can settle a poll before time runs out.
    @Test("Closing a poll early wins over a deadline still ahead")
    func closedEarlyStaysClosed() {
        let poll = Poll(tripId: UUID(), title: "Test", status: .closed, createdBy: UUID(), closesAt: .distantFuture)
        #expect(poll.isOpen(at: Date()) == false)
    }

    @Test("Decodes the deadline, and its absence as no deadline")
    func decodeDeadline() throws {
        func json(_ extra: String) -> Data {
            """
            {
                "id": "11111111-1111-1111-1111-111111111111",
                "trip_id": "22222222-2222-2222-2222-222222222222",
                "title": "Dinner tonight",
                "created_by": "33333333-3333-3333-3333-333333333333"\(extra)
            }
            """.data(using: .utf8)!
        }

        let timed = try Self.supabaseDecoder.decode(Poll.self, from: json(#", "closes_at": "2026-11-20T19:00:00+00:00""#))
        #expect(timed.closesAt == ISO8601DateFormatter().date(from: "2026-11-20T19:00:00Z"))

        let untimed = try Self.supabaseDecoder.decode(Poll.self, from: json(""))
        #expect(untimed.closesAt == nil)
    }

    // Planning choices can wait for everyone to weigh in. On the trip the
    // question is where to go today, and a three-day vote answers it too late.
    @Test("The suggested deadline is three days while planning and three hours on the trip")
    func suggestedDeadline() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(4 * 86_400)
        let trip = Trip(
            id: UUID(), createdBy: UUID(), title: "Lisbon", destination: "Lisbon, Portugal",
            startDate: start, endDate: end, status: .active, isPublic: false,
            createdAt: nil, updatedAt: nil
        )

        #expect(PollDeadline.suggested(for: trip, now: start.addingTimeInterval(-86_400)) == .threeDays)
        #expect(PollDeadline.suggested(for: trip, now: start) == .threeHours)
        // The end date marks the start of the last day, and that day is still the trip.
        #expect(PollDeadline.suggested(for: trip, now: end.addingTimeInterval(12 * 3_600)) == .threeHours)
        #expect(PollDeadline.suggested(for: trip, now: end.addingTimeInterval(2 * 86_400)) == .threeDays)
    }

    @Test("A trip without dates gets the planning deadline")
    func suggestedDeadlineWithoutDates() {
        let trip = Trip(
            id: UUID(), createdBy: UUID(), title: "Someday", destination: "Tokyo, Japan",
            startDate: nil, endDate: nil, status: .planning, isPublic: false,
            createdAt: nil, updatedAt: nil
        )
        #expect(PollDeadline.suggested(for: trip, now: Date()) == .threeDays)
    }

    @Test("Each deadline choice closes the poll that long after it is created")
    func deadlineChoices() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(PollDeadline.none.closesAt(from: now) == nil)
        #expect(PollDeadline.oneHour.closesAt(from: now) == now.addingTimeInterval(3_600))
        #expect(PollDeadline.threeHours.closesAt(from: now) == now.addingTimeInterval(10_800))
        #expect(PollDeadline.oneDay.closesAt(from: now) == now.addingTimeInterval(86_400))
        #expect(PollDeadline.threeDays.closesAt(from: now) == now.addingTimeInterval(259_200))
    }

    // "No deadline" must reach the database as no value at all. A null sent
    // by mistake is harmless, but a missing key is what keeps the choice
    // from ever being read as a time.
    @Test("A poll with no deadline sends no closes_at, and one with a deadline does")
    func createPollPayloadDeadline() throws {
        func keys(closesAt: Date?) throws -> [String: Any] {
            let payload = CreatePollPayload(
                tripId: UUID(), title: "Best beach?", description: nil,
                allowMultiple: false, createdBy: UUID(), closesAt: closesAt
            )
            return try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
        }

        #expect(try keys(closesAt: nil)["closes_at"] == nil)
        #expect(try keys(closesAt: Date())["closes_at"] != nil)
        #expect(try keys(closesAt: Date())["closesAt"] == nil)
    }

    // MARK: - Outcome and turnout

    private static func option(_ title: String, poll: UUID, order: Int, voters: [UUID]) -> PollOption {
        let id = UUID()
        return PollOption(
            id: id, pollId: poll, title: title, sortOrder: order,
            votes: voters.map { PollVote(pollId: poll, optionId: id, userId: $0) }
        )
    }

    // The Decided card names one pick. It must be the option with the most
    // votes, wherever it sits in the list.
    @Test("The option with the most votes is the group's pick")
    func outcomeWinner() throws {
        let pollId = UUID()
        let poll = Poll(id: pollId, tripId: UUID(), title: "Dinner", createdBy: UUID(), options: [
            Self.option("Ramen", poll: pollId, order: 0, voters: [UUID()]),
            Self.option("Sushi", poll: pollId, order: 1, voters: [UUID(), UUID(), UUID()]),
        ])

        guard case .winner(let pick) = poll.outcome else {
            Issue.record("Expected a winner, got \(poll.outcome)")
            return
        }
        #expect(pick.title == "Sushi")
    }

    // Calling the first of two level options the winner would announce a
    // decision the group never made. A tie has to be shown as a tie.
    @Test("Level options are a tie, not a win for whichever comes first")
    func outcomeTie() {
        let pollId = UUID()
        let poll = Poll(id: pollId, tripId: UUID(), title: "Which day?", createdBy: UUID(), options: [
            Self.option("Saturday", poll: pollId, order: 0, voters: [UUID(), UUID()]),
            Self.option("Sunday", poll: pollId, order: 1, voters: [UUID(), UUID()]),
            Self.option("Monday", poll: pollId, order: 2, voters: [UUID()]),
        ])

        guard case .tie(let level) = poll.outcome else {
            Issue.record("Expected a tie, got \(poll.outcome)")
            return
        }
        #expect(level.map(\.title) == ["Saturday", "Sunday"])
    }

    @Test("A poll nobody voted on has no pick")
    func outcomeNoVotes() {
        let pollId = UUID()
        let poll = Poll(id: pollId, tripId: UUID(), title: "Test", createdBy: UUID(), options: [
            Self.option("A", poll: pollId, order: 0, voters: []),
            Self.option("B", poll: pollId, order: 1, voters: []),
        ])

        guard case .noVotes = poll.outcome else {
            Issue.record("Expected no votes, got \(poll.outcome)")
            return
        }
    }

    // "5 of 7 voted" counts people. In a multiple-choice poll one person
    // can cast several votes and must still count once.
    @Test("Turnout counts each person once however many options they chose")
    func voterIdsAreDistinct() {
        let pollId = UUID()
        let amara = UUID()
        let kemi = UUID()
        let poll = Poll(id: pollId, tripId: UUID(), title: "Activities", allowMultiple: true, createdBy: UUID(), options: [
            Self.option("Boat", poll: pollId, order: 0, voters: [amara, kemi]),
            Self.option("Hike", poll: pollId, order: 1, voters: [amara]),
        ])

        #expect(poll.totalVotes == 3)
        #expect(poll.voterIds == [amara, kemi])
    }

    // A poll set to close in three days should say so when it is created.
    // Rounding down would show "2d left" one second later.
    @Test("The countdown rounds to the nearest unit and ends at the deadline")
    func timeLeftText() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let poll = Poll(tripId: UUID(), title: "Test", createdBy: UUID(), closesAt: deadline)

        #expect(poll.timeLeftText(at: deadline.addingTimeInterval(-3 * 86_400 + 5)) == "3d left")
        #expect(poll.timeLeftText(at: deadline.addingTimeInterval(-3 * 3_600 + 5)) == "3h left")
        #expect(poll.timeLeftText(at: deadline.addingTimeInterval(-45 * 60)) == "45m left")
        #expect(poll.timeLeftText(at: deadline.addingTimeInterval(-30)) == "<1m left")
        #expect(poll.timeLeftText(at: deadline) == nil)

        let noDeadline = Poll(tripId: UUID(), title: "Test", createdBy: UUID())
        #expect(noDeadline.timeLeftText(at: Date()) == nil)
    }

    // MARK: - Instant votes

    // The card shows a vote the moment it is tapped, before the server has
    // answered. What it shows has to match what the server will store.

    @Test("In a single-choice poll a new choice replaces the old one")
    func toggleMovesSingleChoiceVote() {
        let pollId = UUID()
        let me = UUID()
        let ramen = Self.option("Ramen", poll: pollId, order: 0, voters: [me])
        let sushi = Self.option("Sushi", poll: pollId, order: 1, voters: [UUID()])
        let poll = Poll(id: pollId, tripId: UUID(), title: "Dinner", createdBy: UUID(), options: [ramen, sushi])

        let after = poll.togglingVote(by: me, profile: nil, on: sushi.id)

        #expect(after.sortedOptions[0].hasVote(by: me) == false)
        #expect(after.sortedOptions[1].hasVote(by: me) == true)
        #expect(after.sortedOptions[1].voteCount == 2)
        #expect(after.totalVotes == 2)
    }

    @Test("In a multiple-choice poll a new choice keeps the earlier ones")
    func toggleAddsMultipleChoiceVote() {
        let pollId = UUID()
        let me = UUID()
        let boat = Self.option("Boat", poll: pollId, order: 0, voters: [me])
        let hike = Self.option("Hike", poll: pollId, order: 1, voters: [])
        let poll = Poll(id: pollId, tripId: UUID(), title: "Activities", allowMultiple: true, createdBy: UUID(), options: [boat, hike])

        let after = poll.togglingVote(by: me, profile: nil, on: hike.id)

        #expect(after.sortedOptions[0].hasVote(by: me) == true)
        #expect(after.sortedOptions[1].hasVote(by: me) == true)
    }

    @Test("Tapping your own choice takes the vote back and leaves other votes alone")
    func toggleRemovesOwnVote() {
        let pollId = UUID()
        let me = UUID()
        let friend = UUID()
        let ramen = Self.option("Ramen", poll: pollId, order: 0, voters: [me, friend])
        let poll = Poll(id: pollId, tripId: UUID(), title: "Dinner", createdBy: UUID(), options: [ramen])

        let after = poll.togglingVote(by: me, profile: nil, on: ramen.id)

        #expect(after.sortedOptions[0].hasVote(by: me) == false)
        #expect(after.sortedOptions[0].hasVote(by: friend) == true)
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
