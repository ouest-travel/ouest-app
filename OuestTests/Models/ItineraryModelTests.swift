import Testing
import Foundation
@testable import Ouest

@Suite("Itinerary Models")
struct ItineraryModelTests {

    // MARK: - ActivityCategory

    @Test("ActivityCategory raw values match database enum strings")
    func categoryRawValues() {
        #expect(ActivityCategory.food.rawValue == "food")
        #expect(ActivityCategory.transport.rawValue == "transport")
        #expect(ActivityCategory.activity.rawValue == "activity")
        #expect(ActivityCategory.accommodation.rawValue == "accommodation")
        #expect(ActivityCategory.other.rawValue == "other")
    }

    @Test("ActivityCategory has labels for all cases")
    func categoryLabels() {
        #expect(ActivityCategory.food.label == "Food")
        #expect(ActivityCategory.transport.label == "Transport")
        #expect(ActivityCategory.activity.label == "Activity")
        #expect(ActivityCategory.accommodation.label == "Accommodation")
        #expect(ActivityCategory.other.label == "Other")
    }

    @Test("ActivityCategory has icons for all cases")
    func categoryIcons() {
        for category in ActivityCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    // MARK: - Activity Time Formatting

    @Test("timeRangeText formats start and end correctly")
    func timeRangeBoth() {
        let activity = makeActivity(startTime: "09:00:00", endTime: "11:30:00")
        let text = activity.timeRangeText
        #expect(text != nil)
        #expect(text!.contains("9:00 AM"))
        #expect(text!.contains("11:30 AM"))
    }

    @Test("timeRangeText shows only start when no end time")
    func timeRangeStartOnly() {
        let activity = makeActivity(startTime: "14:00:00", endTime: nil)
        let text = activity.timeRangeText
        #expect(text != nil)
        #expect(text!.contains("2:00 PM"))
    }

    @Test("timeRangeText returns nil when no start time")
    func timeRangeNone() {
        let activity = makeActivity(startTime: nil, endTime: nil)
        #expect(activity.timeRangeText == nil)
    }

    // MARK: - Activity Coordinates

    @Test("hasCoordinates is true when both lat and lng are present")
    func hasCoords() {
        let activity = makeActivity(latitude: 41.4036, longitude: 2.1744)
        #expect(activity.hasCoordinates == true)
    }

    @Test("hasCoordinates is false when latitude is nil")
    func noLatitude() {
        let activity = makeActivity(latitude: nil, longitude: 2.1744)
        #expect(activity.hasCoordinates == false)
    }

    @Test("hasCoordinates is false when longitude is nil")
    func noLongitude() {
        let activity = makeActivity(latitude: 41.4036, longitude: nil)
        #expect(activity.hasCoordinates == false)
    }

    @Test("hasCoordinates is false when both are nil")
    func noCoords() {
        let activity = makeActivity(latitude: nil, longitude: nil)
        #expect(activity.hasCoordinates == false)
    }

    // MARK: - Activity Cost

    @Test("formattedCost formats USD correctly")
    func formattedCostUSD() {
        let activity = makeActivity(costEstimate: 25, currency: "USD")
        let text = activity.formattedCost
        #expect(text != nil)
        #expect(text!.contains("25"))
    }

    @Test("formattedCost returns nil for zero cost")
    func formattedCostZero() {
        let activity = makeActivity(costEstimate: 0, currency: "USD")
        #expect(activity.formattedCost == nil)
    }

    @Test("formattedCost returns nil for nil cost")
    func formattedCostNil() {
        let activity = makeActivity(costEstimate: nil, currency: nil)
        #expect(activity.formattedCost == nil)
    }

    // MARK: - ItineraryDay Display Title

    @Test("displayTitle shows 'Day N' when no custom title")
    func defaultDisplayTitle() {
        let day = makeDay(dayNumber: 3, title: nil, date: nil)
        #expect(day.displayTitle == "Day 3")
    }

    @Test("displayTitle shows custom title when present")
    func customDisplayTitle() {
        let day = makeDay(dayNumber: 1, title: "Arrival Day", date: nil)
        #expect(day.displayTitle == "Arrival Day")
    }

    @Test("displayTitle appends date when present")
    func displayTitleWithDate() {
        let day = makeDay(dayNumber: 1, title: nil, date: date(2025, 3, 15))
        let title = day.displayTitle
        #expect(title.contains("Day 1"))
        #expect(title.contains("Mar"))
        #expect(title.contains("15"))
    }

    @Test("displayTitle ignores empty string title")
    func emptyTitleFallback() {
        let day = makeDay(dayNumber: 2, title: "", date: nil)
        #expect(day.displayTitle == "Day 2")
    }

    // MARK: - ItineraryDay Sorted Activities

    @Test("sortedActivities orders by sortOrder")
    func sortedActivities() {
        let dayId = UUID()
        let day = makeDay(dayNumber: 1, activities: [
            Activity(dayId: dayId, title: "Third", sortOrder: 2),
            Activity(dayId: dayId, title: "First", sortOrder: 0),
            Activity(dayId: dayId, title: "Second", sortOrder: 1),
        ])
        let sorted = day.sortedActivities
        #expect(sorted[0].title == "First")
        #expect(sorted[1].title == "Second")
        #expect(sorted[2].title == "Third")
    }

    @Test("sortedActivities returns empty for nil activities")
    func sortedActivitiesNil() {
        let day = makeDay(dayNumber: 1, activities: nil)
        #expect(day.sortedActivities.isEmpty)
    }

    // MARK: - ItineraryDay Total Cost

    @Test("totalCost sums activity costs")
    func totalCost() {
        let dayId = UUID()
        let day = makeDay(dayNumber: 1, activities: [
            Activity(dayId: dayId, title: "A", costEstimate: 10, sortOrder: 0),
            Activity(dayId: dayId, title: "B", costEstimate: 25.5, sortOrder: 1),
            Activity(dayId: dayId, title: "C", sortOrder: 2), // no cost
        ])
        #expect(day.totalCost == 35.5)
    }

    @Test("totalCost is zero for no activities")
    func totalCostEmpty() {
        let day = makeDay(dayNumber: 1, activities: [])
        #expect(day.totalCost == 0)
    }

    // MARK: - Helpers

    private func makeActivity(
        startTime: String? = nil,
        endTime: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        costEstimate: Double? = nil,
        currency: String? = nil
    ) -> Activity {
        Activity(
            dayId: UUID(),
            title: "Test Activity",
            locationName: "Test Place",
            latitude: latitude,
            longitude: longitude,
            startTime: startTime,
            endTime: endTime,
            category: .activity,
            costEstimate: costEstimate,
            currency: currency,
            sortOrder: 0
        )
    }

    private func makeDay(
        dayNumber: Int,
        title: String? = nil,
        date: Date? = nil,
        activities: [Activity]? = nil
    ) -> ItineraryDay {
        ItineraryDay(
            tripId: UUID(),
            dayNumber: dayNumber,
            date: date,
            title: title,
            activities: activities
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
