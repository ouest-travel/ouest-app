import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if authViewModel.isLoading {
                SplashView()
            } else if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await authViewModel.restoreSession()
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
