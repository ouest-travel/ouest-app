import Foundation

// MARK: - Poll Status

enum PollStatus: String, Codable, CaseIterable, Sendable {
    case open
    case closed

    var label: String {
        switch self {
        case .open: "Open"
        case .closed: "Closed"
        }
    }

    var icon: String {
        switch self {
        case .open: "chart.bar.fill"
        case .closed: "checkmark.seal.fill"
        }
    }
}

// MARK: - Poll

struct Poll: Codable, Identifiable, Sendable {
    let id: UUID
    let tripId: UUID
    var title: String
    var description: String?
    var status: PollStatus
    var allowMultiple: Bool
    let createdBy: UUID
    let createdAt: Date?
    var updatedAt: Date?
    var closedAt: Date?
    /// When voting stops on its own. Nil means the poll stays open until
    /// someone closes it.
    var closesAt: Date?

    /// Nested from Supabase join
    var options: [PollOption]?
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, options, profile
        case tripId = "trip_id"
        case allowMultiple = "allow_multiple"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case closesAt = "closes_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tripId = try container.decode(UUID.self, forKey: .tripId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(PollStatus.self, forKey: .status) ?? .open
        allowMultiple = try container.decodeIfPresent(Bool.self, forKey: .allowMultiple) ?? false
        createdBy = try container.decode(UUID.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        closesAt = try container.decodeIfPresent(Date.self, forKey: .closesAt)
        options = try? container.decodeIfPresent([PollOption].self, forKey: .options)
        profile = try? container.decodeIfPresent(Profile.self, forKey: .profile)
    }

    init(
        id: UUID = UUID(),
        tripId: UUID,
        title: String,
        description: String? = nil,
        status: PollStatus = .open,
        allowMultiple: Bool = false,
        createdBy: UUID,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        closedAt: Date? = nil,
        closesAt: Date? = nil,
        options: [PollOption]? = nil,
        profile: Profile? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.title = title
        self.description = description
        self.status = status
        self.allowMultiple = allowMultiple
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closedAt = closedAt
        self.closesAt = closesAt
        self.options = options
        self.profile = profile
    }

    // MARK: - Computed

    var isOpen: Bool { isOpen(at: Date()) }

    /// A poll past its deadline is closed even while the stored status still
    /// says open. The database flips the status on a schedule, and voting
    /// has to stop on time whether or not that has happened yet.
    func isOpen(at now: Date) -> Bool {
        guard status == .open else { return false }
        guard let closesAt else { return true }
        return closesAt > now
    }

    var sortedOptions: [PollOption] {
        (options ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalVotes: Int {
        options?.reduce(0) { $0 + $1.voteCount } ?? 0
    }

    /// Everyone who has voted, counted once however many options they chose.
    var voterIds: Set<UUID> {
        Set((options ?? []).flatMap { ($0.votes ?? []).map(\.userId) })
    }

    /// What the group decided. A tie is its own answer rather than a winner
    /// picked by option order: someone in the group has to break it.
    var outcome: PollOutcome {
        let options = sortedOptions
        guard let top = options.map(\.voteCount).max(), top > 0 else { return .noVotes }
        let leaders = options.filter { $0.voteCount == top }
        return leaders.count == 1 ? .winner(leaders[0]) : .tie(leaders)
    }

    /// Short countdown for the card, such as "2h left". Rounded to the nearest
    /// unit so a three-day poll reads "3d left" the moment it is created, not
    /// "2d". Nil when there is no deadline or it has passed.
    func timeLeftText(at now: Date) -> String? {
        guard let closesAt else { return nil }
        let seconds = closesAt.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        let minutes = (seconds / 60).rounded()
        let hours = (seconds / 3_600).rounded()
        let days = (seconds / 86_400).rounded()
        if seconds < 60 { return "<1m left" }
        if minutes < 60 { return "\(Int(minutes))m left" }
        if hours < 24 { return "\(Int(hours))h left" }
        return "\(Int(days))d left"
    }

    /// The poll as it will look once this tap is saved, so the card can
    /// answer at once instead of waiting on the network. Tapping an option
    /// you already chose takes the vote back. In a single-choice poll a new
    /// choice replaces the old one.
    func togglingVote(by userId: UUID, profile: Profile?, on optionId: UUID) -> Poll {
        var copy = self
        let hadVote = options?.first { $0.id == optionId }?.hasVote(by: userId) ?? false
        copy.options = options?.map { option in
            var option = option
            if option.id == optionId || !allowMultiple {
                option.votes?.removeAll { $0.userId == userId }
            }
            if option.id == optionId && !hadVote {
                let vote = PollVote(pollId: id, optionId: optionId, userId: userId, profile: profile)
                option.votes = (option.votes ?? []) + [vote]
            }
            return option
        }
        return copy
    }
}

// MARK: - Poll Outcome

enum PollOutcome: Sendable {
    case winner(PollOption)
    case tie([PollOption])
    case noVotes
}

// MARK: - Poll Deadline

/// How long a new poll stays open. The short choices are there because many
/// group decisions are about today: where to eat tonight cannot wait three days.
enum PollDeadline: String, CaseIterable, Identifiable, Sendable {
    case none
    case oneHour
    case threeHours
    case oneDay
    case threeDays

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "No deadline"
        case .oneHour: "In 1 hour"
        case .threeHours: "In 3 hours"
        case .oneDay: "In 24 hours"
        case .threeDays: "In 3 days"
        }
    }

    private var duration: TimeInterval? {
        switch self {
        case .none: nil
        case .oneHour: 3_600
        case .threeHours: 3 * 3_600
        case .oneDay: 86_400
        case .threeDays: 3 * 86_400
        }
    }

    func closesAt(from now: Date) -> Date? {
        duration.map { now.addingTimeInterval($0) }
    }

    /// Three days while the group is planning, three hours once the trip is
    /// under way and the choices are about today.
    static func suggested(for trip: Trip, now: Date) -> PollDeadline {
        guard let start = trip.startDate, let end = trip.endDate else { return .threeDays }
        // The end date is the start of the trip's last day, which still counts.
        let underWay = now >= start && now < end.addingTimeInterval(86_400)
        return underWay ? .threeHours : .threeDays
    }
}

// MARK: - Poll Option

struct PollOption: Codable, Identifiable, Sendable {
    let id: UUID
    let pollId: UUID
    var title: String
    var sortOrder: Int
    let createdAt: Date?

    /// Nested from Supabase join
    var votes: [PollVote]?

    enum CodingKeys: String, CodingKey {
        case id, title, votes
        case pollId = "poll_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pollId = try container.decode(UUID.self, forKey: .pollId)
        title = try container.decode(String.self, forKey: .title)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        votes = try? container.decodeIfPresent([PollVote].self, forKey: .votes)
    }

    init(
        id: UUID = UUID(),
        pollId: UUID,
        title: String,
        sortOrder: Int = 0,
        createdAt: Date? = nil,
        votes: [PollVote]? = nil
    ) {
        self.id = id
        self.pollId = pollId
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.votes = votes
    }

    // MARK: - Computed

    var voteCount: Int { votes?.count ?? 0 }

    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes)
    }

    func hasVote(by userId: UUID) -> Bool {
        votes?.contains(where: { $0.userId == userId }) ?? false
    }
}

// MARK: - Poll Vote

struct PollVote: Codable, Identifiable, Sendable {
    let id: UUID
    let pollId: UUID
    let optionId: UUID
    let userId: UUID
    let createdAt: Date?

    /// Nested from Supabase join
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, profile
        case pollId = "poll_id"
        case optionId = "option_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pollId = try container.decode(UUID.self, forKey: .pollId)
        optionId = try container.decode(UUID.self, forKey: .optionId)
        userId = try container.decode(UUID.self, forKey: .userId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        profile = try? container.decodeIfPresent(Profile.self, forKey: .profile)
    }

    init(
        id: UUID = UUID(),
        pollId: UUID,
        optionId: UUID,
        userId: UUID,
        createdAt: Date? = nil,
        profile: Profile? = nil
    ) {
        self.id = id
        self.pollId = pollId
        self.optionId = optionId
        self.userId = userId
        self.createdAt = createdAt
        self.profile = profile
    }
}

// MARK: - Payloads

struct CreatePollPayload: Codable, Sendable {
    let tripId: UUID
    let title: String
    let description: String?
    let allowMultiple: Bool
    let createdBy: UUID
    /// Left out of the request when nil, so a poll without a deadline is
    /// stored with none.
    var closesAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case title, description
        case tripId = "trip_id"
        case allowMultiple = "allow_multiple"
        case createdBy = "created_by"
        case closesAt = "closes_at"
    }
}

struct CreatePollOptionPayload: Codable, Sendable {
    let pollId: UUID
    let title: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case title
        case pollId = "poll_id"
        case sortOrder = "sort_order"
    }
}

struct CreatePollVotePayload: Codable, Sendable {
    let pollId: UUID
    let optionId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case optionId = "option_id"
        case userId = "user_id"
    }
}

struct ClosePollPayload: Codable, Sendable {
    let status: PollStatus
    let closedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case closedAt = "closed_at"
    }
}
