import SwiftUI

// MARK: - Deep Link Router

enum DeepLinkRouter {

    /// Represents a parsed deep link destination.
    enum Destination: Equatable {
        case joinTrip(code: String)
        case tripDetail(id: UUID)
        case userProfile(id: UUID)
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

    /// Parses a URL into a navigation destination.
    ///
    /// Supports both formats:
    /// - Custom scheme (legacy/QR codes): `ouest://join/{code}` or `ouest://join?code={code}`
    /// - Universal Link (HTTPS): `https://ouest.travel/join/{code}` or `https://ouest.travel/join?code={code}`
    static func parse(url: URL) -> Destination? {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value

        // Custom scheme: ouest://join/{code}
        if url.scheme == "ouest", url.host() == "join" {
            if let code = pathComponents.first, !code.isEmpty {
                return .joinTrip(code: code)
            }
            if let queryCode, !queryCode.isEmpty {
                return .joinTrip(code: queryCode)
            }
            return nil
        }

        // Universal Link: https://links.ouest.travel/join/{code}
        if (url.scheme == "https" || url.scheme == "http"),
           url.host() == "links.ouest.travel" {
            // pathComponents for /join/ABC123 → ["join", "ABC123"]
            if pathComponents.count >= 2, pathComponents[0] == "join" {
                let code = pathComponents[1]
                if !code.isEmpty { return .joinTrip(code: code) }
            }
            // /join?code=ABC123
            if pathComponents.first == "join", let queryCode, !queryCode.isEmpty {
                return .joinTrip(code: queryCode)
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
