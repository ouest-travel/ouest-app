import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0
    @State private var showCreateTrip = false
    @State private var previousTab = 0
    @State private var notificationsVM = NotificationsViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "safari.fill")
                }
                .tag(1)

            // Placeholder view — tapping the tab opens the create sheet
            Color.clear
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(2)

            NotificationsView(viewModel: notificationsVM)
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .badge(notificationsVM.unreadCount)
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                // Intercept the Create tab — open sheet and revert to previous tab
                showCreateTrip = true
                selectedTab = oldValue
            }
            previousTab = oldValue
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
                .environment(authViewModel)
        }
        .task {
            // Refresh badge on app launch
            await notificationsVM.refreshUnreadCount()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel())
}
