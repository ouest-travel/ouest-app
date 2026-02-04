import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var demoModeManager: DemoModeManager

    @State private var publicTrips: [Trip] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                            Text("Community")
                                .font(OuestTheme.Fonts.title)
                                .foregroundColor(OuestTheme.Colors.text)

                            Text("Discover trips shared by other travelers")
                                .font(OuestTheme.Fonts.subheadline)
                                .foregroundColor(OuestTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, OuestTheme.Spacing.md)

                        // Content
                        if isLoading {
                            loadingView
                        } else if publicTrips.isEmpty {
                            emptyStateView
                        } else {
                            publicTripsListView
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .onAppear {
                loadPublicTrips()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.large)
                    .fill(OuestTheme.Colors.inputBackground)
                    .frame(height: 200)
                    .shimmer()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No public trips yet")
                .font(OuestTheme.Fonts.title3)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Be the first to share your adventure!")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var publicTripsListView: some View {
        LazyVStack(spacing: OuestTheme.Spacing.md) {
            ForEach(publicTrips) { trip in
                CommunityTripCard(trip: trip)
            }
        }
    }

    private func loadPublicTrips() {
        if demoModeManager.isDemoMode {
            publicTrips = DemoModeManager.demoTrips.filter { $0.isPublic }
            isLoading = false
            return
        }

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            publicTrips = []
            isLoading = false
        }
    }
}

struct CommunityTripCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [OuestTheme.Colors.primary, OuestTheme.Colors.indigo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destinationEmoji)
                        .font(.system(size: 32))

                    Text(trip.destination)
                        .font(OuestTheme.Fonts.title3)
                        .foregroundColor(.white)
                }
                .padding(OuestTheme.Spacing.md)
            }
            .frame(height: 140)

            // Details
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text(trip.name)
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)

                if let description = trip.description {
                    Text(description)
                        .font(OuestTheme.Fonts.subheadline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                        .lineLimit(2)
                }

                HStack {
                    // Creator info
                    HStack(spacing: 6) {
                        OuestAvatar(trip.creator, size: .small)
                        Text(trip.creator?.displayNameOrEmail ?? "Unknown")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Date
                    Text(trip.dateRangeFormatted)
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textTertiary)
                }
            }
            .padding(OuestTheme.Spacing.md)
        }
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    CommunityView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
