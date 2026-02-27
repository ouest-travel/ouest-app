import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.pendingDeepLink) private var pendingDeepLink
    @State private var joinInviteCode: String?
    @State private var showJoinSheet = false

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
        .onChange(of: pendingDeepLink.wrappedValue) { _, destination in
            handleDeepLink(destination)
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
            if isAuth, let destination = pendingDeepLink.wrappedValue {
                handleDeepLink(destination)
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            if let code = joinInviteCode {
                JoinTripView(inviteCode: code)
            }
        }
    }

    private func handleDeepLink(_ destination: DeepLinkRouter.Destination?) {
        guard authViewModel.isAuthenticated, let destination else { return }

        switch destination {
        case .joinTrip(let code):
            joinInviteCode = code
            showJoinSheet = true
        }

        pendingDeepLink.wrappedValue = nil
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
