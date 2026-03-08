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
    /// Supports: ouest://join/{code} and ouest://join?code={code}
    static func parse(url: URL) -> Destination? {
        guard url.scheme == "ouest" else { return nil }

        let host = url.host()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "join":
            // ouest://join/{code}
            if let code = pathComponents.first, !code.isEmpty {
                return .joinTrip(code: code)
            }
            // ouest://join?code={code}
            if let queryCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value, !queryCode.isEmpty {
                return .joinTrip(code: queryCode)
            }
            return nil

        default:
            return nil
        }
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
