import Foundation

@MainActor @Observable
final class PollsViewModel {

    // MARK: - List State

    var polls: [Poll] = []
    var isLoading = false

    var failure: OuestError?

    var failureDetail: String?

    /// Trip members, for showing how many have voted and who has not.
    var members: [TripMember] = []

    /// Outcome of an action on a poll that is already on screen.
    var toast: OuestToast?

    // MARK: - Form State

    var pollTitle = ""
    var pollDescription = ""
    var allowMultiple = false
    var optionTexts: [String] = ["", ""]
    var deadline: PollDeadline
    var isSaving = false
    /// Shown in the form when a poll could not be created.
    var formError: String?

    // MARK: - Internal

    let trip: Trip
    private(set) var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
        self.deadline = PollDeadline.suggested(for: trip, now: Date())
    }

    // MARK: - Computed

    var isFormValid: Bool {
        let trimmedTitle = pollTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        let validOptions = optionTexts.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return validOptions.count >= 2
    }

    // MARK: - Load

    func loadPolls() async {
        isLoading = polls.isEmpty

        failure = nil

        failureDetail = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            polls = try await PollService.fetchPolls(tripId: trip.id)
            // Turnout is an extra. If the member list fails the cards fall
            // back to a plain vote count rather than the whole screen failing.
            if members.isEmpty, let fetched = try? await TripService.fetchMembers(tripId: trip.id) {
                members = fetched
            }
        } catch {

            failure = OuestError(error)

            failureDetail = error.localizedDescription

            // With polls already on screen the error screen would hide them.
            if !polls.isEmpty { toast = .failure("Couldn't refresh the polls") }
        }

        isLoading = false
    }

    // MARK: - Create Poll

    func createPoll() async -> Bool {
        guard let userId = currentUserId else { return false }
        isSaving = true
        formError = nil

        do {
            let payload = CreatePollPayload(
                tripId: trip.id,
                title: pollTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: pollDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : pollDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                allowMultiple: allowMultiple,
                createdBy: userId,
                closesAt: deadline.closesAt(from: Date())
            )

            let poll = try await PollService.createPoll(payload)

            // Create options
            let optionPayloads = optionTexts.enumerated().compactMap { index, text -> CreatePollOptionPayload? in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return CreatePollOptionPayload(pollId: poll.id, title: trimmed, sortOrder: index)
            }

            if !optionPayloads.isEmpty {
                try await PollService.createOptions(optionPayloads)
            }

            // Re-fetch to get full nested data
            await loadPolls()
            resetForm()
            isSaving = false
            return true
        } catch {
            formError = "Couldn't create the poll. Check your connection and try again."
            isSaving = false
            return false
        }
    }

    // MARK: - Vote

    func toggleVote(poll: Poll, option: PollOption) async {
        guard let userId = currentUserId, poll.isOpen else { return }

        let alreadyVoted = option.hasVote(by: userId)

        // Show the vote now and save it after, so the card answers the tap.
        // The reload below replaces this guess with what the server stored.
        let before = polls
        if let index = polls.firstIndex(where: { $0.id == poll.id }) {
            let profile = members.first { $0.userId == userId }?.profile
            polls[index] = poll.togglingVote(by: userId, profile: profile, on: option.id)
        }

        do {
            if alreadyVoted {
                // Unvote
                try await PollService.unvote(pollId: poll.id, optionId: option.id, userId: userId)
            } else {
                if !poll.allowMultiple {
                    // Single-choice: remove all existing votes first
                    try await PollService.removeAllVotes(pollId: poll.id, userId: userId)
                }
                // Cast vote
                let payload = CreatePollVotePayload(pollId: poll.id, optionId: option.id, userId: userId)
                try await PollService.vote(payload)
            }

            // Re-fetch to get updated vote data
            await loadPolls()
        } catch {
            polls = before
            toast = .failure("Couldn't save your vote")
            // A single-choice vote removes the old choice before adding the
            // new one, so a failure can leave the server between the two.
            await loadPolls()
        }
    }

    // MARK: - Turnout

    /// Members who have voted on this poll and members still to vote.
    /// Both are empty when the member list is not loaded.
    func turnout(for poll: Poll) -> (voted: [TripMember], waiting: [TripMember]) {
        let voterIds = poll.voterIds
        return (
            members.filter { voterIds.contains($0.userId) },
            members.filter { !voterIds.contains($0.userId) }
        )
    }

    // MARK: - Close Poll

    func closePoll(_ poll: Poll) async {
        do {
            let updated = try await PollService.closePoll(id: poll.id)
            if let index = polls.firstIndex(where: { $0.id == poll.id }) {
                polls[index] = updated
            }
        } catch {
            toast = .failure("Couldn't close the poll")
        }
    }

    // MARK: - Delete Poll

    func deletePoll(_ poll: Poll) async {
        do {
            try await PollService.deletePoll(id: poll.id)
            polls.removeAll { $0.id == poll.id }
        } catch {
            toast = .failure("Couldn't delete the poll")
        }
    }

    // MARK: - Form Helpers

    func addOption() {
        guard optionTexts.count < 10 else { return }
        optionTexts.append("")
    }

    func removeOption(at index: Int) {
        guard optionTexts.count > 2 else { return }
        optionTexts.remove(at: index)
    }

    func resetForm() {
        pollTitle = ""
        pollDescription = ""
        allowMultiple = false
        optionTexts = ["", ""]
        deadline = PollDeadline.suggested(for: trip, now: Date())
        isSaving = false
        formError = nil
    }

    // MARK: - Permission Helpers

    func canClose(_ poll: Poll) -> Bool {
        guard let userId = currentUserId else { return false }
        return poll.createdBy == userId || trip.createdBy == userId
    }

    func canDelete(_ poll: Poll) -> Bool {
        canClose(poll)
    }
}
