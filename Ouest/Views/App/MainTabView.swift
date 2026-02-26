import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "safari.fill")
                }

            CreateTripView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }

            NotificationsView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.primary)
    }
}

#Preview {
    MainTabView()
}
