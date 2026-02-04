import Foundation
import SwiftUI

// MARK: - Community ViewModel

@MainActor
final class CommunityViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var publicTrips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Dependencies

    private let tripRepository: any TripRepositoryProtocol
    private let savedItineraryRepository: any SavedItineraryRepositoryProtocol
    private let currentUserId: String

    // MARK: - Computed Properties

    var hasTrips: Bool {
        !publicTrips.isEmpty
    }

    // MARK: - Initialization

    init(
        tripRepository: any TripRepositoryProtocol,
        savedItineraryRepository: any SavedItineraryRepositoryProtocol,
        currentUserId: String = "demo-user"
    ) {
        self.tripRepository = tripRepository
        self.savedItineraryRepository = savedItineraryRepository
        self.currentUserId = currentUserId
    }

    // MARK: - Save Trip

    func saveTrip(_ trip: Trip) async {
        // Save the trip's itinerary to the user's saved items
        await saveItineraryItem(
            activityName: trip.name,
            activityLocation: trip.destination,
            activityTime: nil,
            activityCost: nil,
            activityDescription: trip.description,
            activityCategory: .activity,
            sourceTripLocation: trip.destination,
            sourceTripUser: trip.creator?.displayNameOrEmail,
            day: nil
        )
    }

    // MARK: - Data Loading

    func loadPublicTrips() async {
        isLoading = true
        error = nil

        do {
            publicTrips = try await tripRepository.getPublicTrips()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        await loadPublicTrips()
    }

    // MARK: - Save Itinerary Item

    func saveItineraryItem(
        activityName: String,
        activityLocation: String,
        activityTime: String?,
        activityCost: String?,
        activityDescription: String?,
        activityCategory: ItineraryCategory,
        sourceTripLocation: String?,
        sourceTripUser: String?,
        day: Int?
    ) async {
        let request = CreateSavedItineraryItemRequest(
            userId: currentUserId,
            activityName: activityName,
            activityLocation: activityLocation,
            activityTime: activityTime,
            activityCost: activityCost,
            activityDescription: activityDescription,
            activityCategory: activityCategory,
            sourceTripLocation: sourceTripLocation,
            sourceTripUser: sourceTripUser,
            day: day
        )

        do {
            _ = try await savedItineraryRepository.saveItem(request)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}
