import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = TripsViewModel()
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.trips.isEmpty {
                    emptyStateView
                } else {
                    tripListView
                }
            }
            .navigationTitle("My Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    greetingView
                }
            }
            .refreshable {
                await viewModel.fetchTrips()
            }
            .task {
                await viewModel.fetchTrips()
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView()
                    .environment(authViewModel)
                    .onDisappear {
                        Task { await viewModel.fetchTrips() }
                    }
            }
        }
    }

    // MARK: - Greeting

    private var greetingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greetingText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let name = authViewModel.currentUser?.fullName?.components(separatedBy: " ").first {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Trip List

    private var tripListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Featured upcoming trip
                if let upcoming = viewModel.upcomingTrip {
                    Section {
                        NavigationLink(value: upcoming.id) {
                            TripCardView(trip: upcoming, style: .featured)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        sectionHeader("Up Next", icon: "sparkles")
                    }
                }

                // Active trips
                if !viewModel.activeTrips.isEmpty {
                    tripSection("Active", icon: "airplane.departure", trips: viewModel.activeTrips)
                }

                // Planning trips
                if !viewModel.planningTrips.isEmpty {
                    tripSection("Planning", icon: "pencil.and.list.clipboard", trips: viewModel.planningTrips)
                }

                // Completed trips
                if !viewModel.completedTrips.isEmpty {
                    tripSection("Completed", icon: "checkmark.circle", trips: viewModel.completedTrips)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationDestination(for: UUID.self) { tripId in
            TripDetailView(tripId: tripId)
                .environment(authViewModel)
        }
    }

    private func tripSection(_ title: String, icon: String, trips: [Trip]) -> some View {
        Section {
            ForEach(trips) { trip in
                NavigationLink(value: trip.id) {
                    TripCardView(trip: trip, style: .standard)
                }
                .buttonStyle(.plain)
            }
        } header: {
            sectionHeader(title, icon: icon)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.teal.gradient)

                Text("Where to next?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your trips will appear here.\nCreate one to start planning!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            OuestButton(title: "Plan a Trip") {
                showCreateTrip = true
            }
            .frame(width: 200)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading trips...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthViewModel())
}
