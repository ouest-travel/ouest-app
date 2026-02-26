import SwiftUI

struct CreateTripView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "plus.circle",
                title: "Create a Trip",
                message: "Start planning your next adventure"
            )
            .navigationTitle("New Trip")
        }
    }
}

#Preview {
    CreateTripView()
}
