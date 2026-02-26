import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "airplane",
                title: "No Trips Yet",
                message: "Create your first trip to start planning your adventure",
                actionTitle: "Create Trip",
                action: {}
            )
            .navigationTitle("My Trips")
        }
    }
}

#Preview {
    HomeView()
}
