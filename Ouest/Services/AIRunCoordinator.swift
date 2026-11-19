import Foundation
import SwiftUI

/// Shared, app-wide state for an in-flight AI itinerary run. Lets us surface a
/// floating "Building your itinerary…" bubble at the root of the app (above
/// the tab bar) so the user keeps seeing progress even if they leave the trip
/// the generation was started on.
///
/// The bubble is purely visual — the actual work runs inside the originating
/// `ItineraryViewModel.generateAIItinerary` / `importAIItinerary` and writes
/// to this coordinator at start / success / failure. On success the bubble
/// auto-clears; on failure it morphs into a red error bubble until the user
/// dismisses or re-opens the relevant trip.
@MainActor
@Observable
final class AIRunCoordinator {
    static let shared = AIRunCoordinator()

    enum Mode: Hashable { case generate, importing }

    var isRunning: Bool = false
    var errorMessage: String?
    var tripId: UUID?
    var tripTitle: String?
    var mode: Mode?

    private init() {}

    func start(tripId: UUID, tripTitle: String?, mode: Mode) {
        self.isRunning = true
        self.errorMessage = nil
        self.tripId = tripId
        self.tripTitle = tripTitle
        self.mode = mode
    }

    func finishSuccess() {
        self.isRunning = false
        // Auto-clear the trip metadata after a moment so the bubble unmounts
        // cleanly. The success state is signalled by the bubble simply
        // disappearing (the new days/activities are visible if the user
        // returns to the trip's itinerary).
        self.tripId = nil
        self.tripTitle = nil
        self.mode = nil
    }

    func finishError(_ message: String) {
        self.isRunning = false
        self.errorMessage = message
        // tripId / tripTitle / mode kept so the bubble can offer "Try again
        // in <trip>" or a retry link.
    }

    /// Called by the bubble's dismiss "x" affordance.
    func clearError() {
        self.errorMessage = nil
        self.tripId = nil
        self.tripTitle = nil
        self.mode = nil
    }
}
