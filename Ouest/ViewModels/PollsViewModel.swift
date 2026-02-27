import Foundation

@MainActor @Observable
final class PollsViewModel {

    // MARK: - List State

    var polls: [Poll] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Form State

    var pollTitle = ""
    var pollDescription = ""
    var allowMultiple = false
    var optionTexts: [String] = ["", ""]
    var isSaving = false

    // MARK: - Internal

    let trip: Trip
    private(set) var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
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
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            polls = try await PollService.fetchPolls(tripId: trip.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create Poll

    func createPoll() async -> Bool {
        guard let userId = currentUserId else { return false }
        isSaving = true
        errorMessage = nil

        do {
            let payload = CreatePollPayload(
                tripId: trip.id,
                title: pollTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: pollDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : pollDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                allowMultiple: allowMultiple,
                createdBy: userId
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
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Vote

    func toggleVote(poll: Poll, option: PollOption) async {
        guard let userId = currentUserId, poll.isOpen else { return }

        let alreadyVoted = option.hasVote(by: userId)

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
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Close Poll

    func closePoll(_ poll: Poll) async {
        do {
            let updated = try await PollService.closePoll(id: poll.id)
            if let index = polls.firstIndex(where: { $0.id == poll.id }) {
                polls[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Poll

    func deletePoll(_ poll: Poll) async {
        do {
            try await PollService.deletePoll(id: poll.id)
            polls.removeAll { $0.id == poll.id }
        } catch {
            errorMessage = error.localizedDescription
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
        isSaving = false
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
