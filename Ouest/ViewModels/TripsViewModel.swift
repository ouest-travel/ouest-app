import Foundation
import Observation

/// Manages the list of user's trips (Home screen)
@MainActor @Observable
final class TripsViewModel {
    var trips: [Trip] = []
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

    func fetchTrips() async {
        isLoading = trips.isEmpty // Only show loading on first load
        errorMessage = nil

        do {
            trips = try await TripService.fetchMyTrips()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteTrip(_ trip: Trip) async -> Bool {
        do {
            try await TripService.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
