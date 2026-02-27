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
        }
    }
}
