import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthNavigationView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OuestTheme.Colors.primary))
                    .scaleEffect(1.5)

                Text("Loading...")
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
