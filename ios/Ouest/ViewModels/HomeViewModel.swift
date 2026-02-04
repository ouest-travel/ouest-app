import Foundation
import SwiftUI

// MARK: - Trip Filter

enum TripFilter: String, CaseIterable {
    case all = "All"
    case planning = "Planning"
    case upcoming = "Upcoming"
    case active = "Active"
    case completed = "Completed"

    var status: TripStatus? {
        switch self {
        case .all: return nil
        case .planning: return .planning
        case .upcoming: return .upcoming
        case .active: return .active
        case .completed: return .completed
        }
    }
}

// MARK: - Home ViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var trips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var selectedFilter: TripFilter = .all

    // MARK: - Dependencies

    private let tripRepository: any TripRepositoryProtocol
    private let userId: String
    private var subscription: (any Cancellable)?

    // MARK: - Computed Properties

    var filteredTrips: [Trip] {
        guard let status = selectedFilter.status else {
            return trips
        }
        return trips.filter { $0.status == status }
    }

    var hasTrips: Bool {
        !filteredTrips.isEmpty
    }

    // MARK: - Initialization

    init(tripRepository: any TripRepositoryProtocol, userId: String) {
        self.tripRepository = tripRepository
        self.userId = userId
    }

    // MARK: - Data Loading

    func loadTrips() async {
        isLoading = true
        error = nil

        do {
            trips = try await tripRepository.getUserTrips(userId: userId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadTrips()
    }

    // MARK: - Real-time Updates

    func startObserving() {
        subscription = tripRepository.observeTrips(userId: userId) { [weak self] updatedTrips in
            Task { @MainActor in
                self?.trips = updatedTrips
            }
        }
    }

    func stopObserving() {
        subscription?.cancel()
        subscription = nil
    }

    // MARK: - Trip Actions

    func createTrip(_ request: CreateTripRequest) async throws -> Trip {
        isLoading = true
        defer { isLoading = false }

        let trip = try await tripRepository.createTrip(request)
        await loadTrips() // Refresh list
        return trip
    }

    func deleteTrip(_ trip: Trip) async {
        guard !trip.isPastTrip else {
            error = "Cannot delete past trips"
            return
        }

        do {
            try await tripRepository.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
