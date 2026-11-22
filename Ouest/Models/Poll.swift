import CoreLocation
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

// MARK: - Poll Kind

/// What the group is choosing between. The kind shapes the form and the
/// card; the voting rules are the same for all three.
enum PollKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case yesNo = "yes_no"
    case place

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "Options"
        case .yesNo: "Yes or no"
        case .place: "Places"
        }
    }

    var icon: String {
        switch self {
        case .text: "list.bullet"
        case .yesNo: "hand.thumbsup"
        case .place: "mappin.and.ellipse"
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
    var kind: PollKind
    /// The option an organiser chose to settle a tie. Nil for a clear winner,
    /// which needs no choosing.
    var pickedOptionId: UUID?
    /// The itinerary activity the pick became. Cleared by the database if
    /// that activity is deleted, which puts the pick back on offer.
    var addedActivityId: UUID?
    var pickDismissedAt: Date?

    /// Nested from Supabase join
    var options: [PollOption]?
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, options, profile, kind
        case pickedOptionId = "picked_option_id"
        case addedActivityId = "added_activity_id"
        case pickDismissedAt = "pick_dismissed_at"
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
        // A kind this build does not know still has options to vote on, so
        // it is shown as a plain poll instead of failing the whole list.
        kind = (try? container.decodeIfPresent(PollKind.self, forKey: .kind)) ?? .text
        pickedOptionId = try container.decodeIfPresent(UUID.self, forKey: .pickedOptionId)
        addedActivityId = try container.decodeIfPresent(UUID.self, forKey: .addedActivityId)
        pickDismissedAt = try container.decodeIfPresent(Date.self, forKey: .pickDismissedAt)
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
        kind: PollKind = .text,
        pickedOptionId: UUID? = nil,
        addedActivityId: UUID? = nil,
        pickDismissedAt: Date? = nil,
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
        self.kind = kind
        self.pickedOptionId = pickedOptionId
        self.addedActivityId = addedActivityId
        self.pickDismissedAt = pickDismissedAt
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

    /// Where the group's pick stands once voting is over. The database
    /// applies the same rule in `poll_pick`, so the two must stay in step.
    var pickState: PollPickState {
        let pick: PollOption
        switch outcome {
        case .noVotes:
            return .none
        case .winner(let option):
            pick = option
        case .tie(let leaders):
            // A choice only counts while it is one of the tied options.
            guard let chosen = leaders.first(where: { $0.id == pickedOptionId }) else {
                return .needsTieBreak(leaders)
            }
            pick = chosen
        }
        if addedActivityId != nil { return .added(pick) }
        if pickDismissedAt != nil { return .dismissed(pick) }
        return .ready(pick)
    }

    /// Whether a pick gives the itinerary something to hold. In a yes or no
    /// poll the options are the words Yes and No, so only an answer that
    /// carries a place can be added. The database refuses the rest.
    func canAddToItinerary(_ option: PollOption) -> Bool {
        kind != .yesNo || option.hasPlace
    }

    /// What the pick is called once it is in the itinerary. A yes or no
    /// answer goes in under its place's name, not the word "Yes". The
    /// database names the activity by the same rule.
    func activityTitle(for option: PollOption) -> String {
        guard kind == .yesNo, let place = option.locationName, !place.isEmpty else { return option.title }
        return place
    }

    /// The place a yes or no poll is asking about, if it has one.
    var subjectPlace: PollOption? {
        guard kind == .yesNo else { return nil }
        return sortedOptions.first(where: \.hasPlace)
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

// MARK: - Poll Pick State

/// What is left to do with a decided poll.
enum PollPickState: Sendable {
    /// Nobody voted, so there is nothing to act on.
    case none
    /// The top options are level. An owner or editor has to choose.
    case needsTieBreak([PollOption])
    /// There is a pick, waiting to be added to the itinerary or dismissed.
    case ready(PollOption)
    case added(PollOption)
    case dismissed(PollOption)
}

// MARK: - Poll Place

/// A place chosen in the new poll form, before the poll is saved.
struct PollPlace: Identifiable, Equatable, Sendable {
    let id = UUID()
    let name: String
    /// Shown in the form so two branches of the same name can be told
    /// apart. Not saved.
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: ActivityCategory

    /// Same name at the same spot, whichever search result it came from.
    func isSamePlace(as other: PollPlace) -> Bool {
        name.caseInsensitiveCompare(other.name) == .orderedSame
            && abs(latitude - other.latitude) < 0.0005
            && abs(longitude - other.longitude) < 0.0005
    }
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
    /// The real place behind this option, when it has one. The winner can
    /// then go into the itinerary without anyone typing it again.
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var category: ActivityCategory?

    /// Nested from Supabase join
    var votes: [PollVote]?

    enum CodingKeys: String, CodingKey {
        case id, title, votes, latitude, longitude, category
        case pollId = "poll_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case locationName = "location_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pollId = try container.decode(UUID.self, forKey: .pollId)
        title = try container.decode(String.self, forKey: .title)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        category = (try? container.decodeIfPresent(ActivityCategory.self, forKey: .category)) ?? nil
        votes = try? container.decodeIfPresent([PollVote].self, forKey: .votes)
    }

    init(
        id: UUID = UUID(),
        pollId: UUID,
        title: String,
        sortOrder: Int = 0,
        createdAt: Date? = nil,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        category: ActivityCategory? = nil,
        votes: [PollVote]? = nil
    ) {
        self.id = id
        self.pollId = pollId
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.votes = votes
    }

    // MARK: - Computed

    var voteCount: Int { votes?.count ?? 0 }

    /// True when the option can be put on a map.
    var hasPlace: Bool { latitude != nil && longitude != nil }

    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes)
    }

    func hasVote(by userId: UUID) -> Bool {
        votes?.contains(where: { $0.userId == userId }) ?? false
    }
}

extension PollOption {
    /// The day whose stops are nearest this place, so the pick lands where
    /// the group will already be. Nil when the option has no place, or no
    /// day has a stop on the map yet. Level days go to the earlier one.
    func nearestDay(in days: [ItineraryDay]) -> ItineraryDay? {
        guard let latitude, let longitude else { return nil }
        let here = CLLocation(latitude: latitude, longitude: longitude)

        func distance(to day: ItineraryDay) -> CLLocationDistance? {
            (day.activities ?? []).compactMap { activity -> CLLocationDistance? in
                guard let lat = activity.latitude, let lng = activity.longitude else { return nil }
                return here.distance(from: CLLocation(latitude: lat, longitude: lng))
            }.min()
        }

        return days
            .sorted { $0.dayNumber < $1.dayNumber }
            .compactMap { day in distance(to: day).map { (day: day, distance: $0) } }
            .min { $0.distance < $1.distance }?
            .day
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
    /// Left out of the request when nil, and the database then stores a
    /// plain text poll.
    var kind: PollKind? = nil

    enum CodingKeys: String, CodingKey {
        case title, description, kind
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
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var category: ActivityCategory? = nil
    /// Set on every option of a poll where any option has a place. Not sent.
    var writesPlaceFields = false

    enum CodingKeys: String, CodingKey {
        case title, latitude, longitude, category
        case pollId = "poll_id"
        case sortOrder = "sort_order"
        case locationName = "location_name"
    }

    /// Options are inserted as one batch, and the API rejects a batch whose
    /// rows have different keys. A yes or no poll can have a place on "Yes"
    /// and none on "No", so in a poll with places an empty place field is
    /// written as null instead of being left out. A poll with no places
    /// sends none of them.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pollId, forKey: .pollId)
        try container.encode(title, forKey: .title)
        try container.encode(sortOrder, forKey: .sortOrder)
        guard writesPlaceFields else { return }
        try container.encode(locationName, forKey: .locationName)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(category, forKey: .category)
    }

    /// The options a new poll is saved with, by kind.
    ///
    /// - text: the typed options, blanks dropped.
    /// - yes or no: always "Yes" then "No". A place, if given, rides on "Yes".
    /// - place: one option per place, named after it. The place's name is
    ///   also its `location_name`, as the itinerary stores places.
    static func options(
        for kind: PollKind,
        pollId: UUID,
        texts: [String],
        places: [PollPlace],
        yesNoPlace: PollPlace?
    ) -> [CreatePollOptionPayload] {
        func placed(_ title: String, _ order: Int, _ place: PollPlace?) -> CreatePollOptionPayload {
            CreatePollOptionPayload(
                pollId: pollId, title: title, sortOrder: order,
                locationName: place?.name, latitude: place?.latitude,
                longitude: place?.longitude, category: place?.category
            )
        }

        var options: [CreatePollOptionPayload]
        switch kind {
        case .text:
            options = texts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { placed($1, $0, nil) }
        case .yesNo:
            options = [placed("Yes", 0, yesNoPlace), placed("No", 1, nil)]
        case .place:
            options = places.enumerated().map { placed($1.name, $0, $1) }
        }

        let anyPlace = options.contains { $0.latitude != nil }
        for index in options.indices { options[index].writesPlaceFields = anyPlace }
        return options
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
