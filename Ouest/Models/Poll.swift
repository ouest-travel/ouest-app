import Foundation
import SwiftUI

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

    var color: Color {
        switch self {
        case .open: .orange
        case .closed: .gray
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
        self.options = options
        self.profile = profile
    }

    // MARK: - Computed

    var isOpen: Bool { status == .open }

    var sortedOptions: [PollOption] {
        (options ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalVotes: Int {
        options?.reduce(0) { $0 + $1.voteCount } ?? 0
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

    enum CodingKeys: String, CodingKey {
        case title, description
        case tripId = "trip_id"
        case allowMultiple = "allow_multiple"
        case createdBy = "created_by"
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
