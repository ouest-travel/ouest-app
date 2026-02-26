import Foundation
import Observation

/// Manages the list of user's trips (Home screen)
@MainActor @Observable
final class TripsViewModel {
    var trips: [Trip] = []
    var tripMembers: [UUID: [TripMemberPreview]] = [:]
    var isLoading = false
    var errorMessage: String?

    /// Filtered trips by status
    var planningTrips: [Trip] { trips.filter { $0.status == .planning } }
    var activeTrips: [Trip] { trips.filter { $0.status == .active } }
    var completedTrips: [Trip] { trips.filter { $0.status == .completed } }

    /// The next upcoming trip (soonest start date in the future)
    var upcomingTrip: Trip? {
        trips
            .filter { $0.status != .completed && $0.startDate != nil && ($0.daysUntilStart ?? 0) >= 0 }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .first
    }

    /// Get member previews for a specific trip
    func membersForTrip(_ trip: Trip) -> [TripMemberPreview] {
        tripMembers[trip.id] ?? []
    }

    func fetchTrips() async {
        isLoading = trips.isEmpty // Only show loading on first load
        errorMessage = nil

        do {
            trips = try await TripService.fetchMyTrips()

            // Batch-fetch member previews for all trips
            if !trips.isEmpty {
                let allMembers = try await TripService.fetchMemberPreviews(
                    tripIds: trips.map(\.id)
                )
                tripMembers = Dictionary(grouping: allMembers, by: \.tripId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteTrip(_ trip: Trip) async -> Bool {
        do {
            try await TripService.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            tripMembers.removeValue(forKey: trip.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateTripStatus(_ trip: Trip, to status: TripStatus) async {
        do {
            let updated = try await TripService.updateTrip(
                id: trip.id,
                UpdateTripPayload(status: status)
            )
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
