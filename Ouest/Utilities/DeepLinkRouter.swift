import SwiftUI

// MARK: - Deep Link Router

enum DeepLinkRouter {

    /// Represents a parsed deep link destination.
    enum Destination: Equatable {
        case joinTrip(code: String)
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
