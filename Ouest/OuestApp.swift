import SwiftUI

@main
struct OuestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authViewModel = AuthViewModel()
    @State private var pendingDeepLink: DeepLinkRouter.Destination?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(\.pendingDeepLink, $pendingDeepLink)
                .onOpenURL { url in
                    pendingDeepLink = DeepLinkRouter.parse(url: url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .notificationTapped)) { output in
                    guard let userInfo = output.userInfo else { return }
                    // Parse APNs payload into a deep-link destination
                    if let typeString = userInfo["type"] as? String,
                       let type = NotificationType(rawValue: typeString) {
                        switch type {
                        case .newFollower:
                            if let followerId = (userInfo["follower_id"] as? String).flatMap(UUID.init(uuidString:)) {
                                pendingDeepLink = .userProfile(id: followerId)
                            }
                        default:
                            if let tripId = (userInfo["trip_id"] as? String).flatMap(UUID.init(uuidString:)) {
                                pendingDeepLink = .tripDetail(id: tripId)
                            }
                        }
                    }
                }
        }
    }
}
