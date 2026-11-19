import Foundation

// MARK: - Poll Service

enum PollService {

    /// Deeply nested select: poll → options → votes → voter profile, plus poll creator profile
    private static let pollSelect = "*, profile:profiles!polls_created_by_fkey(*), options:poll_options(*, votes:poll_votes(*, profile:profiles!poll_votes_user_id_fkey(*)))"

    // MARK: - Polls CRUD

    /// Fetch all polls for a trip, newest first.
    static func fetchPolls(tripId: UUID) async throws -> [Poll] {
        try await SupabaseManager.client
            .from("polls")
            .select(pollSelect)
            .eq("trip_id", value: tripId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Create a new poll (options are added separately via createOptions).
    static func createPoll(_ payload: CreatePollPayload) async throws -> Poll {
        try await SupabaseManager.client
            .from("polls")
            .insert(payload)
            .select(pollSelect)
            .single()
            .execute()
            .value
    }

    /// Batch-insert options for a poll.
    static func createOptions(_ payloads: [CreatePollOptionPayload]) async throws {
        try await SupabaseManager.client
            .from("poll_options")
            .insert(payloads)
            .execute()
    }

    /// Close a poll (set status to closed + timestamp).
    static func closePoll(id: UUID) async throws -> Poll {
        let payload = ClosePollPayload(status: .closed, closedAt: Date())
        return try await SupabaseManager.client
            .from("polls")
            .update(payload)
            .eq("id", value: id)
            .select(pollSelect)
            .single()
            .execute()
            .value
    }

    /// Delete a poll and all its options/votes (cascade).
    static func deletePoll(id: UUID) async throws {
        try await SupabaseManager.client
            .from("polls")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Voting

    /// Cast a vote on a poll option.
    static func vote(_ payload: CreatePollVotePayload) async throws {
        try await SupabaseManager.client
            .from("poll_votes")
            .insert(payload)
            .execute()
    }

    /// Remove a specific vote (unvote from one option).
    static func unvote(pollId: UUID, optionId: UUID, userId: UUID) async throws {
        try await SupabaseManager.client
            .from("poll_votes")
            .delete()
            .eq("poll_id", value: pollId)
            .eq("option_id", value: optionId)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Remove all votes by a user on a poll (used for single-choice switching).
    static func removeAllVotes(pollId: UUID, userId: UUID) async throws {
        try await SupabaseManager.client
            .from("poll_votes")
            .delete()
            .eq("poll_id", value: pollId)
            .eq("user_id", value: userId)
            .execute()
    }
}
