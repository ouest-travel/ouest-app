import Foundation
import SwiftUI

// MARK: - OuestError
//
// Typed error surface. View models classify raw errors at the service
// boundary into one of these five kinds; every UI decision downstream —
// symbol, title, message, recovery action — falls out of the kind alone.
//
// The taxonomy exists to prevent the "someone puts a raw Postgres string
// into errorMessage: String? and the user reads it" pattern that had
// spread across the codebase (see design brief §View-model change).

enum OuestError: Equatable, Sendable {
    /// The device has no working network. Trips already on disk are safe.
    case offline
    /// The requested resource doesn't exist (404) or was deleted.
    case notFound
    /// The user lacks permission — Supabase RLS refused the row.
    case noPermission
    /// The backend threw something we didn't classify (500, decoding, etc.).
    case serverError
    /// Fallback — genuinely unknown. Should be rare after classification.
    case unknown

    /// Classify a raw error at the service boundary. Substring matches on
    /// `localizedDescription` — the same technique EditProfileView uses to
    /// tell a unique-code collision (23505) from other Postgres errors.
    init(_ error: Error) {
        let text = error.localizedDescription.lowercased()
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .dataNotAllowed, .internationalRoamingOff:
                self = .offline
                return
            case .fileDoesNotExist, .resourceUnavailable:
                self = .notFound
                return
            default:
                self = .serverError
                return
            }
        }
        if text.contains("not found") || text.contains("no rows") || text.contains("pgrst116") {
            self = .notFound
        } else if text.contains("permission") || text.contains("row-level security") || text.contains("policy") {
            self = .noPermission
        } else if text.contains("offline") || text.contains("network") || text.contains("connection") {
            self = .offline
        } else if text.contains("server") || text.contains("500") || text.contains("503") {
            self = .serverError
        } else {
            self = .unknown
        }
    }

    /// SF Symbol paired with each kind.
    var symbol: String {
        switch self {
        case .offline:      return "wifi.slash"
        case .notFound:     return "questionmark.folder"
        case .noPermission: return "lock.shield"
        case .serverError:  return "exclamationmark.icloud"
        case .unknown:      return "exclamationmark.triangle"
        }
    }

    /// Screen title. `context` is the noun of what failed to load —
    /// "your expenses", "this trip's members", etc.
    func title(context: String) -> String {
        switch self {
        case .offline:      return "You're offline"
        case .notFound:     return "This trip is gone"
        case .noPermission: return "You don't have access"
        case .serverError:  return "Couldn't load \(context)"
        case .unknown:      return "Something went wrong"
        }
    }

    /// Explanatory body copy.
    var message: String {
        switch self {
        case .offline:
            return "Your trips are saved. We'll sync as soon as you're back on a network."
        case .notFound:
            return "The owner deleted it, or the invite link has expired."
        case .noPermission:
            return "Ask the trip owner to invite you, or join with a code."
        case .serverError:
            return "Something went wrong on our side. Nothing you entered was lost."
        case .unknown:
            return "We couldn't finish that. Try again in a moment."
        }
    }

    /// What the primary action does when the user taps it.
    enum Recovery: Equatable, Sendable {
        case retry
        case dismiss
        case joinWithCode
        case backToTrips
    }

    var recovery: Recovery {
        switch self {
        case .offline:      return .retry
        case .notFound:     return .backToTrips
        case .noPermission: return .joinWithCode
        case .serverError:  return .retry
        case .unknown:      return .retry
        }
    }

    /// Copy for the recovery button.
    var recoveryTitle: String {
        switch recovery {
        case .retry:        return "Try again"
        case .dismiss:      return "Dismiss"
        case .joinWithCode: return "Enter a code"
        case .backToTrips:  return "Back to my trips"
        }
    }
}

// MARK: - OuestErrorState view

/// Full-screen error placeholder. The recovery action is **primary** —
/// the old `ErrorView` rendered "Try Again" in `.secondary`, making the
/// one thing the user should tap the quietest element on screen.
///
/// The raw error string, if provided, is collapsed behind a "Details"
/// disclosure at 11pt monospace on `Fill`. Gated on `#if DEBUG` so it
/// disappears at launch.
struct OuestErrorState: View {
    let error: OuestError

    /// Noun for `.serverError`'s "Couldn't load <context>". Ignored for
    /// other cases whose title is fixed.
    var context: String = "this"

    /// Original error description. Rendered behind the Details disclosure
    /// on debug builds.
    var detail: String? = nil

    /// Runs when the user taps the recovery action.
    var onRecover: () -> Void

    @State private var showDetail = false

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Image(systemName: error.symbol)
                .font(.system(size: OuestTheme.Icon.hero))
                .foregroundStyle(OuestTheme.Colors.errorInk)

            VStack(spacing: OuestTheme.Spacing.sm) {
                Text(error.title(context: context))
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(error.message)
                    .font(OuestTheme.Typography.body)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            OuestButton(title: error.recoveryTitle, action: onRecover)
                .frame(maxWidth: 280)

            #if DEBUG
            if let detail {
                DisclosureGroup(isExpanded: $showDetail) {
                    Text(detail)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(OuestTheme.Colors.textTertiary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(OuestTheme.Spacing.sm)
                        .background(OuestTheme.Colors.fill)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                        .padding(.top, OuestTheme.Spacing.xs)
                } label: {
                    Text("Details")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textTertiary)
                }
                .padding(.top, OuestTheme.Spacing.md)
            }
            #endif
        }
        .padding(OuestTheme.Spacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Offline") {
    OuestErrorState(error: .offline, onRecover: {})
}

#Preview("Server error with detail") {
    OuestErrorState(
        error: .serverError,
        context: "your expenses",
        detail: "PGRST200: The result contains 0 rows",
        onRecover: {}
    )
}

#Preview("No permission — Dark") {
    OuestErrorState(error: .noPermission, onRecover: {})
        .preferredColorScheme(.dark)
}
