import Foundation
import Observation

/// Manages state for the join-trip-via-invite flow.
@MainActor @Observable
final class JoinTripViewModel {
    var preview: InvitePreview?
    var isLoading = false
    var isJoining = false
    var errorMessage: String?

    var failure: OuestError?

    var failureDetail: String?
    var joinedTripId: UUID?

    /// Load the invite preview (trip info) without joining.
    func loadPreview(code: String) async {
        isLoading = true
        errorMessage = nil

        failure = nil

        failureDetail = nil
        do {
            preview = try await TripService.validateInvite(code: code)
        } catch {
            errorMessage = error.localizedDescription

            failure = OuestError(error)

            failureDetail = error.localizedDescription
        }
        isLoading = false
    }

    /// Join the trip via invite code. On success, sets `joinedTripId`.
    func joinTrip(code: String) async {
        isJoining = true
        errorMessage = nil

        failure = nil

        failureDetail = nil
        do {
            joinedTripId = try await TripService.joinViaInvite(code: code)
        } catch {
            errorMessage = error.localizedDescription

            failure = OuestError(error)

            failureDetail = error.localizedDescription
        }
        isJoining = false
    }
}
