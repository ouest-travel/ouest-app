import Testing
import Foundation
@testable import Ouest

@Suite("ItineraryViewModel")
struct ItineraryViewModelTests {

    private func makeTrip() -> Trip {
        Trip(
            id: UUID(),
            createdBy: UUID(),
            title: "Test Trip",
            destination: "Barcelona, Spain",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            status: .planning,
            isPublic: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    @Test("Initial state is empty and not loading")
    @MainActor
    func initialState() {
        let vm = ItineraryViewModel(trip: makeTrip())
        #expect(vm.days.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isSaving == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.editingActivity == nil)
    }

    @Test("resetActivityForm clears all form fields")
    @MainActor
    func resetForm() {
        let vm = ItineraryViewModel(trip: makeTrip())
        // Set some values
        vm.activityTitle = "Test"
        vm.activityDescription = "Desc"
        vm.activityLocationName = "Place"
        vm.activityLatitude = 41.0
        vm.activityLongitude = 2.0
        vm.hasStartTime = true
        vm.hasEndTime = true
        vm.activityCategory = .food
        vm.activityCostText = "50"
        vm.hasCost = true
        vm.editingActivity = Activity(dayId: UUID(), title: "Edit Me", sortOrder: 0)

        vm.resetActivityForm()

        #expect(vm.activityTitle == "")
        #expect(vm.activityDescription == "")
        #expect(vm.activityLocationName == "")
        #expect(vm.activityLatitude == nil)
        #expect(vm.activityLongitude == nil)
        #expect(vm.hasStartTime == false)
        #expect(vm.hasEndTime == false)
        #expect(vm.activityCategory == .activity)
        #expect(vm.activityCostText == "")
        #expect(vm.hasCost == false)
        #expect(vm.editingActivity == nil)
    }

    @Test("isActivityFormValid requires non-empty title")
    @MainActor
    func formValidation() {
        let vm = ItineraryViewModel(trip: makeTrip())
        #expect(vm.isActivityFormValid == false)

        vm.activityTitle = "  "
        #expect(vm.isActivityFormValid == false)

        vm.activityTitle = "Visit Museum"
        #expect(vm.isActivityFormValid == true)
    }

    @Test("populateFormFromActivity sets all form fields from activity")
    @MainActor
    func populateForm() {
        let vm = ItineraryViewModel(trip: makeTrip())
        let activity = Activity(
            dayId: UUID(),
            title: "Sagrada Familia",
            description: "Guided tour",
            locationName: "Barcelona",
            latitude: 41.4036,
            longitude: 2.1744,
            startTime: "10:00:00",
            endTime: "12:00:00",
            category: .activity,
            costEstimate: 35,
            currency: "EUR",
            sortOrder: 1
        )

        vm.populateFormFromActivity(activity)

        #expect(vm.activityTitle == "Sagrada Familia")
        #expect(vm.activityDescription == "Guided tour")
        #expect(vm.activityLocationName == "Barcelona")
        #expect(vm.activityLatitude == 41.4036)
        #expect(vm.activityLongitude == 2.1744)
        #expect(vm.hasStartTime == true)
        #expect(vm.hasEndTime == true)
        #expect(vm.activityCategory == .activity)
        #expect(vm.activityCostText == "35")
        #expect(vm.activityCurrency == "EUR")
        #expect(vm.hasCost == true)
        #expect(vm.editingActivity != nil)
    }

    @Test("allActivitiesWithCoordinates filters correctly")
    @MainActor
    func coordsFilter() {
        let vm = ItineraryViewModel(trip: makeTrip())
        let dayId = UUID()
        vm.days = [
            ItineraryDay(tripId: UUID(), dayNumber: 1, activities: [
                Activity(dayId: dayId, title: "Has Coords", latitude: 41.0, longitude: 2.0, sortOrder: 0),
                Activity(dayId: dayId, title: "No Coords", sortOrder: 1),
            ]),
            ItineraryDay(tripId: UUID(), dayNumber: 2, activities: [
                Activity(dayId: dayId, title: "Also Has Coords", latitude: 40.0, longitude: 3.0, sortOrder: 0),
            ]),
        ]

        #expect(vm.allActivitiesWithCoordinates.count == 2)
        #expect(vm.allActivitiesWithCoordinates[0].activity.title == "Has Coords")
        #expect(vm.allActivitiesWithCoordinates[1].activity.title == "Also Has Coords")
    }

    @Test("totalEstimatedCost sums across all days")
    @MainActor
    func totalCost() {
        let vm = ItineraryViewModel(trip: makeTrip())
        let dayId = UUID()
        vm.days = [
            ItineraryDay(tripId: UUID(), dayNumber: 1, activities: [
                Activity(dayId: dayId, title: "A", costEstimate: 20, sortOrder: 0),
                Activity(dayId: dayId, title: "B", costEstimate: 30, sortOrder: 1),
            ]),
            ItineraryDay(tripId: UUID(), dayNumber: 2, activities: [
                Activity(dayId: dayId, title: "C", costEstimate: 50, sortOrder: 0),
            ]),
        ]

        #expect(vm.totalEstimatedCost == 100)
    }

    @Test("moveActivities reorders local array")
    @MainActor
    func moveActivities() {
        let vm = ItineraryViewModel(trip: makeTrip())
        let dayId = UUID()
        vm.days = [
            ItineraryDay(id: dayId, tripId: UUID(), dayNumber: 1, activities: [
                Activity(dayId: dayId, title: "First", sortOrder: 0),
                Activity(dayId: dayId, title: "Second", sortOrder: 1),
                Activity(dayId: dayId, title: "Third", sortOrder: 2),
            ])
        ]

        // Move first item to end (move from index 0 to index 3 in onMove semantics)
        vm.moveActivities(inDay: dayId, from: IndexSet(integer: 0), to: 3)

        let sorted = vm.days[0].sortedActivities
        #expect(sorted[0].title == "Second")
        #expect(sorted[1].title == "Third")
        #expect(sorted[2].title == "First")
    }
}
