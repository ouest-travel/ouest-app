import SwiftUI

struct NotificationsView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "bell",
                title: "No Activity",
                message: "You'll see trip updates, likes, and comments here"
            )
            .navigationTitle("Activity")
        }
    }
}

#Preview {
    NotificationsView()
}
