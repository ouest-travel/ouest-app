import SwiftUI

// MARK: - Deep Link Router

enum DeepLinkRouter {

    /// Represents a parsed deep link destination.
    enum Destination: Equatable {
        case joinTrip(code: String)
        case tripDetail(id: UUID)
        case userProfile(id: UUID)
        /// Resolved asynchronously by ContentView via TripService.fetchProfile(byHandle:).
        /// Distinct case so the handler knows it must do a lookup before navigating.
        case userProfileByHandle(handle: String)
        /// Supabase auth callback (email confirmation, magic link, password reset).
        /// Carries the full URL — the Supabase client parses tokens off it via
        /// `auth.session(from:)`.
        case authCallback(url: URL)
    }

    /// Creates a navigation destination from an in-app notification.
    static func destination(from notification: AppNotification) -> Destination? {
        switch notification.type {
        case .newFollower:
            guard let id = notification.followerId else { return nil }
            return .userProfile(id: id)
        default:
            guard let tripId = notification.tripId else { return nil }
            return .tripDetail(id: tripId)
        }
    }

    /// Hosts we accept Universal Links from. `links.ouest.travel` is the
    /// pre-existing host (still in entitlements as of this change);
    /// `ouest.travel` is added for share/preview URLs (/t/, /u/).
    private static let universalLinkHosts: Set<String> = [
        "ouest.travel",
        "links.ouest.travel",
    ]

    /// Parses a URL into a navigation destination.
    ///
    /// Supports:
    /// - Custom scheme (legacy/QR codes):
    ///     `ouest://join/{code}` · `ouest://join?code={code}`
    ///     `ouest://u/{handle}`
    /// - Universal Links (HTTPS) at `ouest.travel` or `links.ouest.travel`:
    ///     `/join/{code}` · `/join?code={code}`
    ///     `/t/{code}`           — trip preview/share URL (functionally same as /join)
    ///     `/u/{handle}`         — profile preview/share URL
    ///     `/auth/callback`      — Supabase email confirmation / magic link callback
    static func parse(url: URL) -> Destination? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value

        // MARK: Custom schemes (ouest://...)
        if url.scheme == "ouest" {
            switch url.host() {
            case "join":
                if let code = pathComponents.first, !code.isEmpty {
                    return .joinTrip(code: code)
                }
                if let queryCode, !queryCode.isEmpty {
                    return .joinTrip(code: queryCode)
                }
                return nil
            case "u":
                if let handle = pathComponents.first, !handle.isEmpty {
                    return .userProfileByHandle(handle: handle)
                }
                return nil
            case "auth":
                // ouest://auth/callback?code=… — kept as a fallback so QR/manual
                // paste flows still work if the user opens the email on a
                // device where Universal Links can't route.
                if pathComponents.first == "callback" {
                    return .authCallback(url: url)
                }
                return nil
            default:
                return nil
            }
        }

        // MARK: Universal Links (https://...)
        if (url.scheme == "https" || url.scheme == "http"),
           let host = url.host(), universalLinkHosts.contains(host) {

            // /auth/callback — Supabase auth callback, tokens live in the
            // query/fragment. Hand the whole URL to the Supabase client.
            if pathComponents.count >= 2,
               pathComponents[0] == "auth", pathComponents[1] == "callback" {
                return .authCallback(url: url)
            }
            // /join/{code} or /t/{code} — both resolve to the join/preview flow
            if pathComponents.count >= 2,
               pathComponents[0] == "join" || pathComponents[0] == "t" {
                let code = pathComponents[1]
                if !code.isEmpty { return .joinTrip(code: code) }
            }
            // /join?code={code}
            if pathComponents.first == "join", let queryCode, !queryCode.isEmpty {
                return .joinTrip(code: queryCode)
            }
            // /u/{handle}
            if pathComponents.count >= 2, pathComponents[0] == "u" {
                let handle = pathComponents[1]
                if !handle.isEmpty { return .userProfileByHandle(handle: handle) }
            }
            return nil
        }

        return nil
    }
}

// MARK: - Environment Key for Deep Link State

private struct PendingDeepLinkKey: EnvironmentKey {
    static let defaultValue: Binding<DeepLinkRouter.Destination?> = .constant(nil)
}

extension EnvironmentValues {
    var pendingDeepLink: Binding<DeepLinkRouter.Destination?> {
        get { self[PendingDeepLinkKey.self] }
        set { self[PendingDeepLinkKey.self] = newValue }
    }
}
