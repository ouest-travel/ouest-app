import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.pendingDeepLink) private var pendingDeepLink
    @State private var joinInviteCode: String?
    @State private var showJoinSheet = false
    @State private var deepLinkTripId: UUID?
    @State private var showTripDetail = false
    @State private var deepLinkUserId: UUID?
    @State private var showUserProfile = false

    var body: some View {
        Group {
            if authViewModel.isLoading {
                SplashView()
                    .transition(.opacity)
            } else if authViewModel.isAuthenticated {
                if authViewModel.needsOnboarding {
                    OnboardingView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    MainTabView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            } else {
                LoginView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(OuestTheme.Anim.smooth, value: authViewModel.isLoading)
        .animation(OuestTheme.Anim.smooth, value: authViewModel.isAuthenticated)
        .animation(OuestTheme.Anim.smooth, value: authViewModel.needsOnboarding)
        .task {
            await authViewModel.restoreSession()
        }
        .onChange(of: pendingDeepLink.wrappedValue) { _, destination in
            handleDeepLink(destination)
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuth in
            if isAuth {
                // Handle any pending deep link
                if let destination = pendingDeepLink.wrappedValue {
                    handleDeepLink(destination)
                }
                // Request push notification permission early
                Task {
                    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                    if status == .notDetermined {
                        let granted = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .badge, .sound])
                        if granted == true {
                            await MainActor.run {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            if let code = joinInviteCode {
                JoinTripView(inviteCode: code)
            }
        }
        .sheet(isPresented: $showTripDetail) {
            if let tripId = deepLinkTripId {
                NavigationStack {
                    TripDetailView(tripId: tripId)
                        .environment(authViewModel)
                }
            }
        }
        .sheet(isPresented: $showUserProfile) {
            if let userId = deepLinkUserId {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environment(authViewModel)
                }
            }
        }
    }

    private func handleDeepLink(_ destination: DeepLinkRouter.Destination?) {
        guard authViewModel.isAuthenticated, let destination else { return }

        switch destination {
        case .joinTrip(let code):
            joinInviteCode = code
            showJoinSheet = true
        case .tripDetail(let id):
            deepLinkTripId = id
            showTripDetail = true
        case .userProfile(let id):
            deepLinkUserId = id
            showUserProfile = true
        }

        pendingDeepLink.wrappedValue = nil
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
