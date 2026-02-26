import SwiftUI

struct ExploreView: View {
    @State private var viewModel = CommunityFeedViewModel()
    @State private var contentAppeared = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.feedTrips.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.loadFeed() }
                    }
                } else if viewModel.filteredTrips.isEmpty && !viewModel.searchQuery.isEmpty {
                    searchEmptyState
                } else if viewModel.feedTrips.isEmpty {
                    EmptyStateView(
                        icon: "safari",
                        title: "No Trips Yet",
                        message: "Be the first to share a trip with the community!"
                    )
                } else {
                    feedList
                }
            }
            .navigationTitle("Explore")
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search trips, destinations, travelers…"
            )
            .refreshable {
                await viewModel.refreshFeed()
            }
            .navigationDestination(for: UUID.self) { tripId in
                TripDetailView(tripId: tripId)
            }
            .sheet(isPresented: $viewModel.showComments) {
                if let tripId = viewModel.selectedCommentTripId {
                    CommentsView(tripId: tripId)
                        .presentationDetents([.medium, .large])
                }
            }
            .overlay {
                if viewModel.isCloning {
                    cloningOverlay
                }
            }
            .task {
                if viewModel.feedTrips.isEmpty {
                    await viewModel.loadFeed()
                }
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(Array(viewModel.filteredTrips.enumerated()), id: \.element.id) { index, feedTrip in
                    FeedTripCardView(
                        feedTrip: feedTrip,
                        onLike: { viewModel.toggleLike(feedTrip) },
                        onSave: { viewModel.toggleSave(feedTrip) },
                        onComment: { viewModel.openComments(for: feedTrip.id) },
                        onClone: {
                            Task { await viewModel.cloneTrip(feedTrip) }
                        }
                    )
                    .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.05)
                    .onAppear {
                        // Trigger pagination when last item appears
                        if feedTrip.id == viewModel.filteredTrips.last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(OuestTheme.Spacing.lg)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    feedCardSkeleton
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
        }
    }

    private var feedCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author header skeleton
            HStack(spacing: OuestTheme.Spacing.sm) {
                Circle()
                    .fill(OuestTheme.Colors.surfaceSecondary)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OuestTheme.Colors.surfaceSecondary)
                        .frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OuestTheme.Colors.surfaceSecondary)
                        .frame(width: 80, height: 10)
                }

                Spacer()
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.sm)

            // Cover skeleton
            RoundedRectangle(cornerRadius: 0)
                .fill(OuestTheme.Colors.surfaceSecondary)
                .frame(height: 200)

            // Action bar skeleton
            HStack(spacing: OuestTheme.Spacing.xl) {
                Circle()
                    .fill(OuestTheme.Colors.surfaceSecondary)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(OuestTheme.Colors.surfaceSecondary)
                    .frame(width: 24, height: 24)
                Spacer()
                Circle()
                    .fill(OuestTheme.Colors.surfaceSecondary)
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.sm)
        }
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
        .shadow(OuestTheme.Shadow.md)
        .shimmerEffect()
    }

    // MARK: - Empty States

    private var searchEmptyState: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("No results")
                .font(OuestTheme.Typography.cardTitle)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Cloning Overlay

    private var cloningOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: OuestTheme.Spacing.md) {
                ProgressView()
                    .tint(.white)
                Text("Cloning trip…")
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(.white)
            }
            .padding(OuestTheme.Spacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        }
    }
}

#Preview {
    ExploreView()
}
