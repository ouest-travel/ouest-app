import SwiftUI

@main
struct OuestApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var demoModeManager = DemoModeManager()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(demoModeManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
