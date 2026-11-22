import Foundation

// MARK: - Poll Service

enum PollService {

    /// Deeply nested select: poll → options → votes → voter profile, plus poll creator profile.
    /// The options link is named so that a second link between the two
    /// tables can never make the request ambiguous and fail the whole list.
    private static let pollSelect = "*, profile:profiles!polls_created_by_fkey(*), options:poll_options!poll_options_poll_id_fkey(*, votes:poll_votes(*, profile:profiles!poll_votes_user_id_fkey(*)))"

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

    // MARK: - Group Pick

    // These three go through database functions. An editor who did not
    // create the poll cannot update it directly, and adding the pick writes
    // the activity and the poll together or not at all.

    /// Settle a tie by choosing one of the tied options.
    static func breakTie(pollId: UUID, optionId: UUID) async throws {
        try await SupabaseManager.client
            .rpc("break_poll_tie", params: ["_poll_id": pollId.uuidString, "_option_id": optionId.uuidString])
            .execute()
    }

    /// Put the group's pick into a day of the itinerary.
    static func addPickToDay(pollId: UUID, dayId: UUID) async throws {
        try await SupabaseManager.client
            .rpc("add_poll_pick_to_day", params: ["_poll_id": pollId.uuidString, "_day_id": dayId.uuidString])
            .execute()
    }

    /// Mark the pick as one the group is not adding.
    static func dismissPick(pollId: UUID) async throws {
        try await SupabaseManager.client
            .rpc("dismiss_poll_pick", params: ["_poll_id": pollId.uuidString])
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
