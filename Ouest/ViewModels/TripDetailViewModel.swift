import Foundation
import Observation
import SwiftUI

/// Manages state for a single trip's detail view + creation/editing
@MainActor @Observable
final class TripDetailViewModel {
    // MARK: - Trip state
    var trip: Trip?
    var members: [TripMember] = []
    var isLoading = false
    var isSaving = false
    // Typed error surface — brief §View-model change.

    var failure: OuestError?

    var failureDetail: String?
    var successMessage: String?

    // MARK: - Form fields (used for create + edit)
    var title = ""
    var destination = ""
    var description = ""
    var startDate = Date()
    var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
    var hasDates = true
    var isPublic = false
    var coverImageData: Data?
    /// Edit Trip "Reset to destination photo": drop the current cover so a
    /// stock photo of the destination takes its place on save.
    var resetCoverToStock = false
    var budgetText = ""
    var currency = "USD"
    var hasBudget = false
    var countryCodes: [String] = []

    // MARK: - Weather
    /// The daily forecast for this trip's destination. `nil` when we haven't
    /// fetched, when preconditions weren't met (no dates, > 10 days out,
    /// already ended), or when geocoding found no match. The view treats those
    /// cases identically: no weather section rendered.
    var forecast: DailyForecast?
    var weatherFailure: OuestError?
    var isLoadingWeather = false

    // MARK: - Members search
    var searchQuery = ""
    var searchResults: [Profile] = []
    var isSearching = false

    // MARK: - Invite state
    var invites: [TripInvite] = []
    var activeInvite: TripInvite?
    var isGeneratingInvite = false
    var inviteError: String?

    /// Current user's role in this trip
    var myRole: MemberRole? {
        members.first(where: { $0.userId == currentUserId })?.role
    }

    var canEdit: Bool {
        myRole?.canEdit ?? false
    }

    /// Whether the current user is a member of this trip
    var isMember: Bool {
        myRole != nil
    }

    private var currentUserId: UUID?

    /// Lightweight init for standalone sharing (e.g., from HomeView context menu).
    /// Sets trip and resolves current user without a full network load.
    func prepareForSharing(trip: Trip) async {
        self.trip = trip
        self.currentUserId = try? await SupabaseManager.client.auth.session.user.id
    }

    // MARK: - Load Trip

    func loadTrip(id: UUID) async {
        isLoading = true
        failure = nil

        failureDetail = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            trip = try await TripService.fetchTrip(id: id)
            members = try await TripService.fetchMembers(tripId: id)
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
        }

        isLoading = false

        // Kick off weather without blocking trip render — the section has its
        // own skeleton and error states.
        Task { await self.loadForecast() }

        // Trips created before stock covers existed (or whose first lookup
        // failed) get one the next time an editor opens them.
        if trip?.coverImageUrl == nil, canEdit {
            Task { await self.applyStockCover(to: id) }
        }
    }

    // MARK: - Stock Cover

    /// Best-effort: ask the backend for an Unsplash photo of the destination
    /// and reflect it locally. Never surfaces an error — the gradient
    /// placeholder is an acceptable fallback, not a failure the user caused.
    private func applyStockCover(to tripId: UUID) async {
        do {
            guard let cover = try await TripService.applyDestinationCover(tripId: tripId),
                  trip?.id == tripId else { return }
            trip?.coverImageUrl = cover.url
            trip?.coverAttribution = cover.photographer
            trip?.coverAttributionUrl = cover.photographerUrl
        } catch {
            #if DEBUG
            print("[TripDetail] stock cover failed: \(error)")
            #endif
        }
    }

    // MARK: - Load Forecast
    //
    // Preconditions live here rather than in the view so `WeatherSection` can
    // stay a pure presentation surface. `loadForecast()` returns silently when
    // the trip has no dates, is more than 10 days out, or has already ended —
    // the view then reads `forecast == nil && weatherFailure == nil` to hide
    // the section entirely.

    func loadForecast() async {
        guard !isLoadingWeather, let trip = trip else { return }

        guard let start = trip.startDate else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: start)
        let daysUntilStart = calendar.dateComponents([.day], from: today, to: startDay).day ?? 0

        // WeatherKit's daily forecast reaches ~10 days out. Fetching earlier
        // would just paint a "no data" state.
        guard daysUntilStart <= 10 else { return }

        // Trip already ended — no forward-looking weather is useful.
        if let end = trip.endDate {
            let endDay = calendar.startOfDay(for: end)
            let daysSinceEnd = calendar.dateComponents([.day], from: endDay, to: today).day ?? 0
            guard daysSinceEnd <= 0 else { return }
        }

        isLoadingWeather = true
        weatherFailure = nil

        do {
            guard let coord = try await GeocodingService.geocode(trip.destination) else {
                // "Home" / "TBD" / typo — hide the section rather than error.
                isLoadingWeather = false
                return
            }
            forecast = try await WeatherService.fetchDailyForecast(
                latitude: coord.latitude,
                longitude: coord.longitude
            )
        } catch {
            weatherFailure = OuestError(error)
        }

        isLoadingWeather = false
    }

    // MARK: - Create Trip

    func createTrip() async -> Trip? {
        isSaving = true
        failure = nil

        failureDetail = nil

        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            currentUserId = userId

            // Upload cover image if provided
            var coverUrl: String?
            if let imageData = coverImageData {
                let tempId = UUID()
                coverUrl = try await StorageService.uploadTripCover(
                    data: imageData,
                    userId: userId,
                    tripId: tempId
                )
            }

            let payload = CreateTripPayload(
                createdBy: userId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                coverImageUrl: coverUrl,
                startDate: hasDates ? startDate : nil,
                endDate: hasDates ? endDate : nil,
                status: .planning,
                isPublic: isPublic,
                budget: hasBudget ? Double(budgetText) : nil,
                currency: hasBudget ? currency : nil,
                countryCodes: countryCodes.isEmpty ? nil : countryCodes
            )

            let newTrip = try await TripService.createTrip(payload)

            // If we uploaded a cover with a temp ID, re-upload with real trip ID
            if let imageData = coverImageData {
                let finalUrl = try await StorageService.uploadTripCover(
                    data: imageData,
                    userId: userId,
                    tripId: newTrip.id
                )
                _ = try await TripService.updateTrip(
                    id: newTrip.id,
                    UpdateTripPayload(coverImageUrl: finalUrl)
                )
            }

            // Auto-generate itinerary days if trip has dates
            if hasDates {
                _ = try? await ItineraryService.generateDaysForTrip(
                    tripId: newTrip.id,
                    startDate: startDate,
                    endDate: endDate
                )
            }

            trip = newTrip

            // No upload → stock photo of the destination. Done before
            // returning so the Home card and detail hero both show it.
            if coverImageData == nil {
                await applyStockCover(to: newTrip.id)
            }

            isSaving = false
            return trip ?? newTrip
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    // MARK: - Update Trip

    func updateTrip() async -> Bool {
        guard let tripId = trip?.id else { return false }
        isSaving = true
        failure = nil

        failureDetail = nil

        do {
            let userId = try await SupabaseManager.client.auth.session.user.id
            let previousDestination = trip?.destination
            let hadStockCover = trip?.hasStockCover ?? false

            // Fields the user toggled off must be sent as explicit nulls —
            // omitting them would leave the previous value in place.
            var cleared: [UpdateTripPayload.CodingKeys] = []
            if !hasDates { cleared += [.startDate, .endDate] }
            if !hasBudget { cleared.append(.budget) }

            // Upload new cover image if changed
            var coverUrl = trip?.coverImageUrl
            if let imageData = coverImageData {
                coverUrl = try await StorageService.uploadTripCover(
                    data: imageData,
                    userId: userId,
                    tripId: tripId
                )
                // A user photo replaces a stock one; drop the stale credit.
                cleared += [.coverAttribution, .coverAttributionUrl]
            } else if resetCoverToStock {
                // Clearing the cover is what makes the stock lookup below
                // run — and what tells the server it may write one.
                coverUrl = nil
                cleared += [.coverImageUrl, .coverAttribution, .coverAttributionUrl]
            }

            let payload = UpdateTripPayload(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                coverImageUrl: coverUrl,
                startDate: hasDates ? startDate : nil,
                endDate: hasDates ? endDate : nil,
                isPublic: isPublic,
                budget: hasBudget ? Double(budgetText) : nil,
                currency: hasBudget ? currency : nil,
                countryCodes: countryCodes,
                nullFields: cleared
            )

            trip = try await TripService.updateTrip(id: tripId, payload)

            // Still no cover, or a stock cover for a destination that just
            // changed → fetch a (new) stock photo. User uploads are left alone.
            let destinationChanged = previousDestination != trip?.destination
            if coverImageData == nil,
               trip?.coverImageUrl == nil || (hadStockCover && destinationChanged) {
                await applyStockCover(to: tripId)
            }

            // Keep itinerary days in sync with the trip's current range.
            // Covers all cases in one call: dates added for the first time
            // (generates the full range), start shifted (re-aligns existing
            // day dates), end extended (appends missing days). Non-destructive
            // when the range shrinks — extra days stay so we don't delete
            // user activities behind their back.
            if hasDates {
                try? await ItineraryService.syncDayDatesToTrip(
                    tripId: tripId,
                    startDate: startDate,
                    endDate: endDate
                )
            }

            isSaving = false
            return true
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Populate form fields from an existing trip (for editing)
    func populateFromTrip(_ trip: Trip) {
        self.trip = trip
        title = trip.title
        destination = trip.destination
        description = trip.description ?? ""
        startDate = trip.startDate ?? Date()
        endDate = trip.endDate ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
        hasDates = trip.startDate != nil
        isPublic = trip.isPublic
        hasBudget = trip.budget != nil && trip.budget! > 0
        budgetText = trip.budget.map { String(format: "%.0f", $0) } ?? ""
        currency = trip.currency ?? "USD"
        countryCodes = trip.countryCodes ?? []
        resetCoverToStock = false
    }

    // MARK: - Members

    func searchUsers() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        do {
            let results = try await TripService.searchProfiles(query: query)
            // Filter out existing members
            let memberIds = Set(members.map(\.userId))
            searchResults = results.filter { !memberIds.contains($0.id) }
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func inviteMember(profile: Profile, role: MemberRole = .viewer) async -> Bool {
        guard let tripId = trip?.id, let userId = currentUserId else { return false }

        do {
            let payload = AddMemberPayload(
                tripId: tripId,
                userId: profile.id,
                role: role,
                invitedBy: userId
            )
            let member = try await TripService.addMember(payload)
            members.append(member)
            searchResults.removeAll { $0.id == profile.id }
            return true
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
            return false
        }
    }

    func removeMember(_ member: TripMember) async -> Bool {
        do {
            try await TripService.removeMember(memberId: member.id)
            members.removeAll { $0.id == member.id }
            return true
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
            return false
        }
    }

    func updateRole(member: TripMember, to role: MemberRole) async {
        do {
            try await TripService.updateMemberRole(memberId: member.id, role: role)
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                members[index].role = role
            }
        } catch {
            failure = OuestError(error)

            failureDetail = error.localizedDescription
        }
    }

    // MARK: - Invite Links

    func fetchInvites() async {
        guard let tripId = trip?.id else { return }
        do {
            invites = try await TripService.fetchInvites(tripId: tripId)
            activeInvite = invites.first(where: { $0.isValid })
        } catch {
            inviteError = error.localizedDescription
        }
    }

    func generateInvite(role: MemberRole = .viewer) async {
        guard let tripId = trip?.id, let userId = currentUserId else { return }
        isGeneratingInvite = true
        inviteError = nil
        defer { isGeneratingInvite = false }

        // Up to 2 attempts, but ONLY retry on a unique-code collision — any
        // other error (network, auth, RLS) fails fast so we don't burn our
        // one retry on a non-collision then surface a stale error message.
        // 23505 surfaces in localizedDescription as "duplicate key value
        // violates unique constraint …" — same detection style as
        // EditProfileView.applySaveError.
        for attempt in 0..<2 {
            do {
                let payload = CreateInvitePayload(
                    tripId: tripId,
                    createdBy: userId,
                    code: TripService.generateInviteCode(),
                    role: role,
                    expiresAt: nil,
                    maxUses: 0
                )
                let invite = try await TripService.createInvite(payload)
                invites.insert(invite, at: 0)
                activeInvite = invite
                return
            } catch {
                let desc = error.localizedDescription.lowercased()
                let isCollision = desc.contains("duplicate key")
                    || desc.contains("unique constraint")
                if isCollision && attempt == 0 {
                    continue  // Roll a new code and try once more.
                }
                inviteError = isCollision
                    ? "Couldn't generate a unique code. Please try again."
                    : error.localizedDescription
                return
            }
        }
    }

    func revokeInvite(_ invite: TripInvite) async {
        do {
            try await TripService.revokeInvite(id: invite.id)
            // Refetch to get updated state
            await fetchInvites()
        } catch {
            inviteError = error.localizedDescription
        }
    }
}
