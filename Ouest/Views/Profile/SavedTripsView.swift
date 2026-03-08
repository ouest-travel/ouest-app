import SwiftUI

struct SavedTripsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var savedTrips: [Trip] = []
    @State private var tripMembers: [UUID: [TripMemberPreview]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var contentAppeared = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage, savedTrips.isEmpty {
                ErrorView(message: error) {
                    Task { await loadSavedTrips() }
                }
            } else if savedTrips.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    title: "No Saved Trips",
                    message: "Bookmark trips from Explore to save them for later"
                )
            } else {
                tripsList
            }
        }
        .navigationTitle("Saved Trips")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: UUID.self) { tripId in
            TripDetailView(tripId: tripId)
                .environment(authViewModel)
        }
        .task {
            await loadSavedTrips()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            contentAppeared = false
            await loadSavedTrips()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Trips List

    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.md) {
                ForEach(Array(savedTrips.enumerated()), id: \.element.id) { index, trip in
                    NavigationLink(value: trip.id) {
                        TripCardView(
                            trip: trip,
                            style: .standard,
                            members: tripMembers[trip.id] ?? []
                        )
                    }
                    .buttonStyle(ScaledButtonStyle(scale: 0.98))
                    .cardEntrance(isVisible: contentAppeared, delay: Double(index) * 0.06)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.md)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonTripCard()
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.md)
        }
    }

    // MARK: - Data Loading

    private func loadSavedTrips() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        isLoading = savedTrips.isEmpty
        errorMessage = nil

        do {
            savedTrips = try await CommunityService.fetchSavedTrips(userId: userId)

            if !savedTrips.isEmpty {
                let tripIds = savedTrips.map(\.id)
                let members = (try? await TripService.fetchMemberPreviews(tripIds: tripIds)) ?? []
                tripMembers = Dictionary(grouping: members, by: \.tripId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        SavedTripsView()
            .environment(AuthViewModel())
    }
}
