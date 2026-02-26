import Testing
import Foundation
@testable import Ouest

@Suite("TripsViewModel")
struct TripsViewModelTests {

    @Test("Initial state is empty and not loading")
    @MainActor
    func initialState() {
        let vm = TripsViewModel()
        #expect(vm.trips.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("Filtered trip arrays work correctly")
    @MainActor
    func filteredTrips() {
        let vm = TripsViewModel()
        vm.trips = [
            makeTrip(status: .planning),
            makeTrip(status: .planning),
            makeTrip(status: .active),
            makeTrip(status: .completed),
        ]

        #expect(vm.planningTrips.count == 2)
        #expect(vm.activeTrips.count == 1)
        #expect(vm.completedTrips.count == 1)
    }

    @Test("upcomingTrip returns soonest future trip")
    @MainActor
    func upcomingTrip() {
        let vm = TripsViewModel()
        let soon = makeTrip(
            title: "Soon",
            status: .planning,
            start: Date().addingTimeInterval(5 * 86400)
        )
        let later = makeTrip(
            title: "Later",
            status: .planning,
            start: Date().addingTimeInterval(30 * 86400)
        )
        let past = makeTrip(
            title: "Past",
            status: .completed,
            start: Date().addingTimeInterval(-10 * 86400)
        )

        vm.trips = [later, past, soon]
        #expect(vm.upcomingTrip?.title == "Soon")
    }

    @Test("upcomingTrip is nil when no trips")
    @MainActor
    func noUpcomingTrip() {
        let vm = TripsViewModel()
        #expect(vm.upcomingTrip == nil)
    }

    @Test("fetchTrips with Supabase configured")
    @MainActor
    func fetchTrips() async throws {
        try #require(Secrets.isConfigured, "Supabase not configured — skipping network test")
        let vm = TripsViewModel()
        await vm.fetchTrips()
        // Should complete without crashing, may return empty array for fresh account
        #expect(vm.isLoading == false)
    }

    // MARK: - Helper

    private func makeTrip(
        title: String = "Test",
        status: TripStatus = .planning,
        start: Date? = nil
    ) -> Trip {
        Trip(
            id: UUID(),
            createdBy: UUID(),
            title: title,
            destination: "Somewhere",
            description: nil,
            coverImageUrl: nil,
            startDate: start,
            endDate: start.map { $0.addingTimeInterval(7 * 86400) },
            status: status,
            isPublic: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
