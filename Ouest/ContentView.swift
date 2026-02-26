import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if authViewModel.isLoading {
                SplashView()
                    .transition(.opacity)
            } else if authViewModel.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                LoginView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(OuestTheme.Anim.smooth, value: authViewModel.isLoading)
        .animation(OuestTheme.Anim.smooth, value: authViewModel.isAuthenticated)
        .task {
            await authViewModel.restoreSession()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
