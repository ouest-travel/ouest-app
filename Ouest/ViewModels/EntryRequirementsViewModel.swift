import Foundation
import Observation

/// Manages state for the entry requirements view — fetches visa data from Travel Buddy API.
@MainActor @Observable
final class EntryRequirementsViewModel {
    var results: [EntryRequirementResult] = []
    var passportCountry: String?
    var isLoading = false
    var needsNationality = false
    var needsCountryCodes = false

    /// Load visa requirements for each destination country in the trip.
    func loadRequirements(for trip: Trip, userNationality: String?) async {
        // Validate passport nationality
        guard let passport = userNationality, !passport.isEmpty else {
            needsNationality = true
            return
        }

        // Validate destination countries
        guard let destinations = trip.countryCodes, !destinations.isEmpty else {
            needsCountryCodes = true
            return
        }

        passportCountry = passport
        needsNationality = false
        needsCountryCodes = false
        isLoading = true

        results = await EntryRequirementService.checkVisas(
            passport: passport,
            destinations: destinations
        )

        isLoading = false
    }
}
