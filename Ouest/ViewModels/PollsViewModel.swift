import Foundation
import MapKit

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

    // MARK: - Group Pick State

    /// The trip's days, loaded when someone goes to add a pick to one.
    var days: [ItineraryDay] = []
    var isLoadingDays = false
    var daysFailed = false
    /// The poll whose pick is being settled, added or dismissed.
    var resolvingPollId: UUID?

    // MARK: - Form State

    var pollTitle = ""
    var pollDescription = ""
    var allowMultiple = false
    var optionTexts: [String] = ["", ""]
    var kind: PollKind = .text
    /// The places a place poll chooses between.
    var places: [PollPlace] = []
    /// The place a yes or no poll is asking about. Optional.
    var yesNoPlace: PollPlace?
    var deadline: PollDeadline
    var isSaving = false
    /// Shown in the form when a poll could not be created.
    var formError: String?

    // MARK: - Place Search State

    var placeQuery = ""
    var placeResults: [MKMapItem] = []
    var isSearchingPlaces = false
    /// Where the trip is, so a search for "pizza" finds pizza there and not
    /// near the phone. Looked up once.
    private var destinationRegion: MKCoordinateRegion?

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
        switch kind {
        case .text:
            let validOptions = optionTexts.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return validOptions.count >= 2
        case .yesNo:
            return true
        case .place:
            return places.count >= 2
        }
    }

    var canAddPlace: Bool { places.count < 10 }

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
                // Yes or no has one answer per person by definition.
                allowMultiple: kind == .yesNo ? false : allowMultiple,
                createdBy: userId,
                closesAt: deadline.closesAt(from: Date()),
                kind: kind == .text ? nil : kind
            )

            let poll = try await PollService.createPoll(payload)

            // Create options
            let optionPayloads = CreatePollOptionPayload.options(
                for: kind, pollId: poll.id, texts: optionTexts,
                places: places, yesNoPlace: yesNoPlace
            )

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

    // MARK: - Group Pick

    func loadDays() async {
        isLoadingDays = days.isEmpty
        daysFailed = false
        do {
            days = try await ItineraryService.fetchDays(tripId: trip.id)
        } catch {
            daysFailed = true
        }
        isLoadingDays = false
    }

    func breakTie(_ poll: Poll, choosing option: PollOption) async {
        await resolve(poll, failure: "Couldn't settle the tie") {
            try await PollService.breakTie(pollId: poll.id, optionId: option.id)
        }
    }

    /// Returns true when the pick is now in the itinerary.
    func addPick(of poll: Poll, to day: ItineraryDay) async -> Bool {
        let added = await resolve(poll, failure: "Couldn't add it to the itinerary") {
            try await PollService.addPickToDay(pollId: poll.id, dayId: day.id)
        }
        if added { toast = .success("Added to Day \(day.dayNumber)") }
        return added
    }

    func dismissPick(of poll: Poll) async {
        await resolve(poll, failure: "Couldn't dismiss the pick") {
            try await PollService.dismissPick(pollId: poll.id)
        }
    }

    /// Runs one pick action, then reloads so the card shows what the
    /// database decided rather than a guess.
    @discardableResult
    private func resolve(_ poll: Poll, failure: String, _ action: () async throws -> Void) async -> Bool {
        guard resolvingPollId == nil else { return false }
        resolvingPollId = poll.id
        defer { resolvingPollId = nil }
        do {
            try await action()
            await loadPolls()
            return true
        } catch {
            toast = .failure(failure)
            return false
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

    // MARK: - Place Search

    func searchPlaces() async {
        let query = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            placeResults = []
            return
        }

        isSearchingPlaces = true
        if destinationRegion == nil,
           let coordinate = try? await GeocodingService.geocode(trip.destination) {
            destinationRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let destinationRegion { request.region = destinationRegion }

        let results = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        // A slower, older search must not replace the results of a newer one.
        if query == placeQuery.trimmingCharacters(in: .whitespacesAndNewlines) {
            placeResults = results
        }
        isSearchingPlaces = false
    }

    /// Adds the place to a place poll, or makes it the subject of a yes or
    /// no poll. Returns false when a place poll already has it.
    @discardableResult
    func choosePlace(_ item: MKMapItem) -> Bool {
        let place = Self.place(from: item)
        clearPlaceSearch()

        if kind == .yesNo {
            yesNoPlace = place
            return true
        }
        guard canAddPlace, !places.contains(where: { $0.isSamePlace(as: place) }) else { return false }
        places.append(place)
        return true
    }

    /// True when a place poll already offers this search result.
    func hasPlace(_ item: MKMapItem) -> Bool {
        guard kind == .place else { return false }
        return places.contains { $0.isSamePlace(as: Self.place(from: item)) }
    }

    private static func place(from item: MKMapItem) -> PollPlace {
        let coordinate = item.placemark.coordinate
        return PollPlace(
            name: item.name ?? "Unnamed place",
            // The street address, so two branches of one name can be told apart.
            address: item.placemark.title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: ActivityCategory.from(pointOfInterest: item.pointOfInterestCategory)
        )
    }

    func removePlace(_ place: PollPlace) {
        places.removeAll { $0.id == place.id }
    }

    func clearPlaceSearch() {
        placeQuery = ""
        placeResults = []
        isSearchingPlaces = false
    }

    func resetForm() {
        pollTitle = ""
        pollDescription = ""
        allowMultiple = false
        optionTexts = ["", ""]
        kind = .text
        places = []
        yesNoPlace = nil
        clearPlaceSearch()
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
