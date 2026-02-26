import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "safari",
                title: "Explore",
                message: "Discover trips and itineraries from the community"
            )
            .navigationTitle("Explore")
        }
    }
}

#Preview {
    ExploreView()
}
