import SwiftUI

struct CommunityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: CommunityViewModel

    init(repositories: RepositoryProvider? = nil) {
        let repos = repositories ?? RepositoryProvider()
        _viewModel = StateObject(wrappedValue: CommunityViewModel(
            tripRepository: repos.tripRepository,
            savedItineraryRepository: repos.savedItineraryRepository
        ))
    }

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
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.publicTrips.isEmpty {
                            emptyStateView
                        } else {
                            publicTripsListView
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .task {
                await viewModel.loadPublicTrips()
            }
            .refreshable {
                await viewModel.refresh()
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
            ForEach(viewModel.publicTrips) { trip in
                CommunityTripCard(trip: trip) {
                    Task {
                        await viewModel.saveTrip(trip)
                    }
                }
            }
        }
    }
}

struct CommunityTripCard: View {
    let trip: Trip
    let onSave: () -> Void

    @State private var isSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .topTrailing) {
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

                // Save button
                Button {
                    isSaved.toggle()
                    onSave()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.white)
                        .padding(OuestTheme.Spacing.sm)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(OuestTheme.Spacing.sm)
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
    CommunityView(repositories: RepositoryProvider(isDemoMode: true))
        .environmentObject(AppState(isDemoMode: true))
}
