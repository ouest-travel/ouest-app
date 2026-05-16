import Foundation
import Observation
import MapKit

/// Manages the itinerary for a single trip (days + activities)
@MainActor @Observable
final class ItineraryViewModel {

    // MARK: - State

    var days: [ItineraryDay] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    // MARK: - Navigation State

    var selectedDay: ItineraryDay?
    var showAddActivity = false
    var editingActivity: Activity?
    var showMap = false
    var showQuickAdd = false
    var quickAddTargetDay: ItineraryDay?

    // MARK: - Map View State

    /// Day filter on the map view. nil = show all days
    var selectedDayFilter: ItineraryDay?

    /// Whether to draw connecting trail lines between stops on the map
    var showMapTrails = true

    // MARK: - AI Itinerary State

    var isGeneratingAI = false
    var aiError: String?
    var showAIGenerate = false
    var showAIImport = false

    // MARK: - Activity Form Fields

    var activityTitle = ""
    var activityDescription = ""
    var activityLocationName = ""
    var activityLatitude: Double?
    var activityLongitude: Double?
    var activityStartTime = Date()
    var activityEndTime = Date()
    var hasStartTime = false
    var hasEndTime = false
    var activityCategory: ActivityCategory = .activity
    var activityCostText = ""
    var activityCurrency = "USD"
    var hasCost = false

    // MARK: - Place Search

    var searchQuery = ""
    var searchResults: [MKMapItem] = []
    var isSearching = false

    // MARK: - Trip Reference

    let trip: Trip
    private var currentUserId: UUID?

    init(trip: Trip) {
        self.trip = trip
    }

    // MARK: - Computed

    var isActivityFormValid: Bool {
        !activityTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var allActivitiesWithCoordinates: [(day: ItineraryDay, activity: Activity)] {
        days.flatMap { day in
            day.sortedActivities
                .filter(\.hasCoordinates)
                .map { (day: day, activity: $0) }
        }
    }

    /// Days that have at least one activity with coordinates — used for filter chips
    var daysWithCoordinates: [ItineraryDay] {
        days.filter { $0.activitiesWithCoordinatesCount > 0 }
    }

    var totalEstimatedCost: Double {
        days.reduce(0) { $0 + $1.totalCost }
    }

    // MARK: - Load Itinerary

    func loadItinerary() async {
        isLoading = days.isEmpty
        errorMessage = nil

        do {
            currentUserId = try await SupabaseManager.client.auth.session.user.id
            let fetched = try await ItineraryService.fetchDays(tripId: trip.id)

            if fetched.isEmpty, let start = trip.startDate, let end = trip.endDate {
                // Auto-generate days from trip date range (lazy fallback)
                days = try await ItineraryService.generateDaysForTrip(
                    tripId: trip.id,
                    startDate: start,
                    endDate: end
                )
            } else {
                days = fetched
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Manually generate days from trip dates (called from empty state button)
    func generateDaysFromTripDates() async {
        guard let start = trip.startDate, let end = trip.endDate else { return }
        isLoading = true
        errorMessage = nil

        do {
            days = try await ItineraryService.generateDaysForTrip(
                tripId: trip.id,
                startDate: start,
                endDate: end
            )
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }

        isLoading = false
    }

    // MARK: - Day CRUD

    func addDay() async {
        isSaving = true
        let nextNumber = (days.map(\.dayNumber).max() ?? 0) + 1

        // If trip has dates, calculate the date for this new day
        var dayDate: Date?
        if let start = trip.startDate {
            var cal = Calendar.current
            cal.timeZone = TimeZone(identifier: "UTC")!
            dayDate = cal.date(byAdding: .day, value: nextNumber - 1, to: start)
        }

        do {
            let payload = CreateDayPayload(
                tripId: trip.id,
                dayNumber: nextNumber,
                date: dayDate,
                title: nil,
                notes: nil
            )
            let day = try await ItineraryService.createDay(payload)
            days.append(day)
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }
        isSaving = false
    }

    func updateDay(_ day: ItineraryDay, title: String?, notes: String?) async {
        let payload = UpdateDayPayload(title: title, notes: notes)
        do {
            let updated = try await ItineraryService.updateDay(id: day.id, payload)
            if let index = days.firstIndex(where: { $0.id == day.id }) {
                days[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDay(_ day: ItineraryDay) async {
        do {
            try await ItineraryService.deleteDay(id: day.id)
            days.removeAll { $0.id == day.id }
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }
    }

    // MARK: - Activity Form Lifecycle

    func resetActivityForm() {
        activityTitle = ""
        activityDescription = ""
        activityLocationName = ""
        activityLatitude = nil
        activityLongitude = nil
        activityStartTime = Date()
        activityEndTime = Date()
        hasStartTime = false
        hasEndTime = false
        activityCategory = .activity
        activityCostText = ""
        activityCurrency = "USD"
        hasCost = false
        editingActivity = nil
        searchQuery = ""
        searchResults = []
    }

    func populateFormFromActivity(_ activity: Activity) {
        editingActivity = activity
        activityTitle = activity.title
        activityDescription = activity.description ?? ""
        activityLocationName = activity.locationName ?? ""
        activityLatitude = activity.latitude
        activityLongitude = activity.longitude
        activityCategory = activity.category
        activityCostText = activity.costEstimate.map { String(format: "%.0f", $0) } ?? ""
        activityCurrency = activity.currency ?? "USD"
        hasCost = activity.costEstimate != nil && activity.costEstimate! > 0
        hasStartTime = activity.startTime != nil
        hasEndTime = activity.endTime != nil
        if let t = activity.startTime { activityStartTime = parseTimeString(t) ?? Date() }
        if let t = activity.endTime { activityEndTime = parseTimeString(t) ?? Date() }
    }

    // MARK: - Activity CRUD

    func saveActivity(forDay day: ItineraryDay) async -> Bool {
        guard let userId = currentUserId else { return false }
        isSaving = true

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let startTimeStr = hasStartTime ? timeFormatter.string(from: activityStartTime) : nil
        let endTimeStr = hasEndTime ? timeFormatter.string(from: activityEndTime) : nil
        let trimmedTitle = activityTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let editing = editingActivity {
                // Update existing
                let payload = UpdateActivityPayload(
                    title: trimmedTitle,
                    description: activityDescription.isEmpty ? nil : activityDescription,
                    locationName: activityLocationName.isEmpty ? nil : activityLocationName,
                    latitude: activityLatitude,
                    longitude: activityLongitude,
                    startTime: startTimeStr,
                    endTime: endTimeStr,
                    category: activityCategory,
                    costEstimate: hasCost ? Double(activityCostText) : nil,
                    currency: hasCost ? activityCurrency : nil
                )
                let updated = try await ItineraryService.updateActivity(id: editing.id, payload)
                updateActivityInDay(day.id, activity: updated)
            } else {
                // Create new
                let existingCount = days.first(where: { $0.id == day.id })?.activities?.count ?? 0
                let payload = CreateActivityPayload(
                    dayId: day.id,
                    title: trimmedTitle,
                    description: activityDescription.isEmpty ? nil : activityDescription,
                    locationName: activityLocationName.isEmpty ? nil : activityLocationName,
                    latitude: activityLatitude,
                    longitude: activityLongitude,
                    startTime: startTimeStr,
                    endTime: endTimeStr,
                    category: activityCategory,
                    costEstimate: hasCost ? Double(activityCostText) : nil,
                    currency: hasCost ? activityCurrency : nil,
                    sortOrder: existingCount,
                    createdBy: userId
                )
                let created = try await ItineraryService.createActivity(payload)
                appendActivityToDay(day.id, activity: created)
            }
            HapticFeedback.success()
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
            isSaving = false
            return false
        }
    }

    func deleteActivity(_ activity: Activity, fromDay dayId: UUID) async {
        do {
            try await ItineraryService.deleteActivity(id: activity.id)
            if let dayIndex = days.firstIndex(where: { $0.id == dayId }) {
                days[dayIndex].activities?.removeAll { $0.id == activity.id }
            }
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reorder

    func moveActivities(inDay dayId: UUID, from source: IndexSet, to destination: Int) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayId }) else { return }

        // Sort first so we're operating on the displayed order
        var sorted = days[dayIndex].sortedActivities
        sorted.move(fromOffsets: source, toOffset: destination)

        // Update local state with new sort orders
        for (index, var activity) in sorted.enumerated() {
            activity.sortOrder = index
            sorted[index] = activity
        }
        days[dayIndex].activities = sorted

        // Persist in background
        let updates = sorted.enumerated().map { (index, act) in
            (id: act.id, sortOrder: index)
        }
        Task {
            try? await ItineraryService.reorderActivities(updates)
        }

        HapticFeedback.selection()
    }

    // MARK: - Quick-Add from Search

    /// Instantly create an activity from a map search result — no full form needed.
    func quickAddActivity(from mapItem: MKMapItem, toDay day: ItineraryDay) async -> Bool {
        guard let userId = currentUserId else { return false }
        let name = mapItem.name ?? "Unnamed Place"
        let coord = mapItem.placemark.coordinate
        let category = ActivityCategory.from(pointOfInterest: mapItem.pointOfInterestCategory)
        let existingCount = days.first(where: { $0.id == day.id })?.activities?.count ?? 0

        do {
            let payload = CreateActivityPayload(
                dayId: day.id,
                title: name,
                description: nil,
                locationName: mapItem.placemark.formattedAddress,
                latitude: coord.latitude,
                longitude: coord.longitude,
                startTime: nil,
                endTime: nil,
                category: category,
                costEstimate: nil,
                currency: nil,
                sortOrder: existingCount,
                createdBy: userId
            )
            let created = try await ItineraryService.createActivity(payload)
            appendActivityToDay(day.id, activity: created)
            HapticFeedback.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
            return false
        }
    }

    // MARK: - Reorder Days

    func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)

        // Reassign dayNumber (1-indexed) and recalculate dates
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!

        for i in days.indices {
            days[i].dayNumber = i + 1
            if let start = trip.startDate {
                days[i].date = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: start))
            }
        }

        // Persist in background
        let updates = days.map { (id: $0.id, dayNumber: $0.dayNumber, date: $0.date) }
        Task {
            try? await ItineraryService.reorderDays(updates)
        }

        HapticFeedback.selection()
    }

    // MARK: - AI Itinerary

    /// Calls the AI Edge Function to generate a full itinerary, then reloads.
    /// Returns true on success so the calling view can dismiss itself.
    @discardableResult
    func generateAIItinerary(preferences: TripPreferences) async -> Bool {
        guard let userId = currentUserId else {
            aiError = "Sign in required."
            return false
        }
        guard let startDate = trip.startDate, let endDate = trip.endDate else {
            aiError = "Trip dates are required for AI generation. Edit your trip and add start/end dates."
            return false
        }

        isGeneratingAI = true
        aiError = nil

        do {
            _ = try await AIItineraryService.generateItinerary(
                tripId: trip.id,
                userId: userId,
                destination: trip.destination,
                startDate: startDate,
                endDate: endDate,
                preferences: preferences
            )
            // Refresh from DB to pick up the newly inserted days + activities.
            await loadItinerary()
            HapticFeedback.success()
            isGeneratingAI = false
            return true
        } catch {
            aiError = error.localizedDescription
            HapticFeedback.error()
            isGeneratingAI = false
            return false
        }
    }

    /// Imports an itinerary from pasted text or a URL (TikTok caption, Instagram post,
    /// YouTube link, blog article, or freeform notes). Returns true on success.
    @discardableResult
    func importAIItinerary(inputText: String) async -> Bool {
        guard let userId = currentUserId else {
            aiError = "Sign in required."
            return false
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else {
            aiError = "Paste at least a short description, a caption, or a link."
            return false
        }

        isGeneratingAI = true
        aiError = nil

        do {
            _ = try await AIItineraryService.importItinerary(
                tripId: trip.id,
                userId: userId,
                inputText: trimmed,
                startDate: trip.startDate,
                endDate: trip.endDate
            )
            await loadItinerary()
            HapticFeedback.success()
            isGeneratingAI = false
            return true
        } catch {
            aiError = error.localizedDescription
            HapticFeedback.error()
            isGeneratingAI = false
            return false
        }
    }

    // MARK: - Place Search

    func searchPlaces() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // Bias search toward trip destination if available
        if let tripCoord = tripCoordinate {
            request.region = MKCoordinateRegion(
                center: tripCoord,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func selectPlace(_ mapItem: MKMapItem) {
        activityLocationName = mapItem.name ?? ""
        activityLatitude = mapItem.placemark.coordinate.latitude
        activityLongitude = mapItem.placemark.coordinate.longitude
        searchQuery = ""
        searchResults = []
    }

    func clearSelectedPlace() {
        activityLocationName = ""
        activityLatitude = nil
        activityLongitude = nil
    }

    // MARK: - Private Helpers

    private func updateActivityInDay(_ dayId: UUID, activity: Activity) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayId }),
              let actIndex = days[dayIndex].activities?.firstIndex(where: { $0.id == activity.id }) else { return }
        days[dayIndex].activities?[actIndex] = activity
    }

    private func appendActivityToDay(_ dayId: UUID, activity: Activity) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayId }) else { return }
        if days[dayIndex].activities == nil {
            days[dayIndex].activities = []
        }
        days[dayIndex].activities?.append(activity)
    }

    private func parseTimeString(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)
    }

    /// Approximate coordinate for trip destination (for search region bias)
    private var tripCoordinate: CLLocationCoordinate2D? {
        // Use the first activity's coordinates as a proxy for destination
        allActivitiesWithCoordinates.first.map {
            CLLocationCoordinate2D(latitude: $0.activity.latitude!, longitude: $0.activity.longitude!)
        }
    }
}
