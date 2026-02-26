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
    var errorMessage: String?
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
    var budgetText = ""
    var currency = "USD"
    var hasBudget = false

    // MARK: - Members search
    var searchQuery = ""
    var searchResults: [Profile] = []
    var isSearching = false

    /// Current user's role in this trip
    var myRole: MemberRole? {
        members.first(where: { $0.userId == currentUserId })?.role
    }

    var canEdit: Bool {
        myRole?.canEdit ?? false
    }

    private var currentUserId: UUID?

    // MARK: - Load Trip

    func loadTrip(id: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            trip = try await TripService.fetchTrip(id: id)
            members = try await TripService.fetchMembers(tripId: id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create Trip

    func createTrip() async -> Trip? {
        isSaving = true
        errorMessage = nil

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
                currency: hasBudget ? currency : nil
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
                try? await ItineraryService.generateDaysForTrip(
                    tripId: newTrip.id,
                    startDate: startDate,
                    endDate: endDate
                )
            }

            trip = newTrip
            isSaving = false
            return newTrip
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }

    // MARK: - Update Trip

    func updateTrip() async -> Bool {
        guard let tripId = trip?.id else { return false }
        isSaving = true
        errorMessage = nil

        do {
            let userId = try await SupabaseManager.client.auth.session.user.id

            // Upload new cover image if changed
            var coverUrl = trip?.coverImageUrl
            if let imageData = coverImageData {
                coverUrl = try await StorageService.uploadTripCover(
                    data: imageData,
                    userId: userId,
                    tripId: tripId
                )
            }

            let payload = UpdateTripPayload(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                coverImageUrl: coverUrl,
                startDate: hasDates ? startDate : nil,
                endDate: hasDates ? endDate : nil,
                isPublic: isPublic,
                budget: hasBudget ? Double(budgetText) : nil,
                currency: hasBudget ? currency : nil
            )

            let oldTrip = trip
            trip = try await TripService.updateTrip(id: tripId, payload)

            // If dates were added/changed, auto-generate itinerary days (only if none exist)
            if hasDates && (oldTrip?.startDate == nil || oldTrip?.endDate == nil) {
                let existingDays = try await ItineraryService.fetchDays(tripId: tripId)
                if existingDays.isEmpty {
                    try? await ItineraryService.generateDaysForTrip(
                        tripId: tripId,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }

            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            return false
        }
    }

    func removeMember(_ member: TripMember) async -> Bool {
        do {
            try await TripService.removeMember(memberId: member.id)
            members.removeAll { $0.id == member.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }
}
