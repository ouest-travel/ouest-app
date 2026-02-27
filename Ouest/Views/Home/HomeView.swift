import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = TripsViewModel()
    @State private var showCreateTrip = false
    @State private var cardsAppeared = false

    // Context menu state
    @State private var tripToDelete: Trip?
    @State private var tripToEdit: Trip?
    @State private var tripToShare: Trip?
    @State private var showPastTrips = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    skeletonLoadingView
                } else if viewModel.trips.isEmpty {
                    emptyStateView
                } else {
                    tripListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
            .refreshable {
                cardsAppeared = false
                await viewModel.fetchTrips()
                withAnimation(OuestTheme.Anim.smooth) {
                    cardsAppeared = true
                }
            }
            .task {
                await viewModel.fetchTrips()
                withAnimation(OuestTheme.Anim.smooth) {
                    cardsAppeared = true
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView()
                    .environment(authViewModel)
                    .onDisappear {
                        Task { await viewModel.fetchTrips() }
                    }
            }
            .sheet(item: $tripToEdit) { trip in
                editTripSheet(for: trip)
            }
            .sheet(item: $tripToShare) { trip in
                ShareTripSheet(trip: trip)
            }
            .alert("Delete Trip", isPresented: deleteAlertBinding) {
                Button("Cancel", role: .cancel) {
                    tripToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete {
                        Task {
                            HapticFeedback.success()
                            await viewModel.deleteTrip(trip)
                        }
                    }
                    tripToDelete = nil
                }
            } message: {
                if let trip = tripToDelete {
                    Text("Are you sure you want to delete \"\(trip.title)\"? This cannot be undone.")
                }
            }
        }
    }

    // MARK: - Delete Alert Binding

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )
    }

    // MARK: - Edit Sheet

    private func editTripSheet(for trip: Trip) -> some View {
        let vm = TripDetailViewModel()
        vm.populateFromTrip(trip)
        return EditTripView(viewModel: vm)
            .environment(authViewModel)
            .onDisappear {
                Task { await viewModel.fetchTrips() }
            }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            // Functional label
            Text("My Trips")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .warmReveal(isVisible: cardsAppeared, delay: 0)

            // Hero greeting
            Text(personalGreeting)
                .font(OuestTheme.Typography.heroTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
                .warmReveal(isVisible: cardsAppeared, delay: 0.12)

            // Name + time-of-day icon
            if let firstName {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Text(firstName)
                        .font(OuestTheme.Typography.screenTitle)
                        .foregroundStyle(OuestTheme.Colors.brand)

                    Image(systemName: greetingIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(greetingIconGradient)
                        .bouncyAppear(isVisible: cardsAppeared, delay: 0.35)
                }
                .warmReveal(isVisible: cardsAppeared, delay: 0.22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Greeting Helpers

    private var firstName: String? {
        authViewModel.currentUser?.fullName?.components(separatedBy: " ").first
    }

    private var personalGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12:  base = "Good morning"
        case 12..<17: base = "Good afternoon"
        default:      base = "Good evening"
        }
        return firstName != nil ? "\(base)," : base
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "sun.max.fill"
        case 12..<17: return "sun.horizon.fill"
        default:      return "moon.stars.fill"
        }
    }

    private var greetingIconGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
        case 12..<17:
            return LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Trip List

    private var tripListView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                // Greeting + title header
                greetingHeader

                // Featured upcoming trip
                if let upcoming = viewModel.upcomingTrip {
                    Section {
                        NavigationLink(value: upcoming.id) {
                            TripCardView(
                                trip: upcoming,
                                style: .featured,
                                members: viewModel.membersForTrip(upcoming)
                            )
                        }
                        .buttonStyle(ScaledButtonStyle(scale: 0.98))
                        .contextMenu { tripContextMenu(for: upcoming) }
                        .fadeSlideIn(isVisible: cardsAppeared, delay: 0)
                    } header: {
                        sectionHeader("Up Next", icon: "sparkles")
                    }
                }

                // Active trips
                if !viewModel.activeTrips.isEmpty {
                    tripSection("Active", icon: "airplane.departure", trips: viewModel.activeTrips, startIndex: 1)
                }

                // Planning trips
                if !viewModel.planningTrips.isEmpty {
                    tripSection("Planning", icon: "pencil.and.list.clipboard", trips: viewModel.planningTrips, startIndex: viewModel.activeTrips.count + 1)
                }

                // Past trips (collapsible)
                if !viewModel.completedTrips.isEmpty {
                    pastTripsSection
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
        .navigationDestination(for: UUID.self) { tripId in
            TripDetailView(tripId: tripId)
                .environment(authViewModel)
        }
    }

    private func tripSection(_ title: String, icon: String, trips: [Trip], startIndex: Int) -> some View {
        Section {
            ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                NavigationLink(value: trip.id) {
                    TripCardView(
                        trip: trip,
                        style: .standard,
                        members: viewModel.membersForTrip(trip)
                    )
                }
                .buttonStyle(ScaledButtonStyle(scale: 0.98))
                .contextMenu { tripContextMenu(for: trip) }
                .fadeSlideIn(isVisible: cardsAppeared, delay: Double(startIndex + index) * 0.06)
            }
        } header: {
            sectionHeader(title, icon: icon)
        }
    }

    // MARK: - Past Trips (Collapsible)

    private var pastTripsSection: some View {
        Section {
            if showPastTrips {
                ForEach(Array(viewModel.completedTrips.enumerated()), id: \.element.id) { index, trip in
                    NavigationLink(value: trip.id) {
                        TripCardView(
                            trip: trip,
                            style: .standard,
                            members: viewModel.membersForTrip(trip)
                        )
                    }
                    .buttonStyle(ScaledButtonStyle(scale: 0.98))
                    .contextMenu { tripContextMenu(for: trip) }
                    .fadeSlideIn(isVisible: showPastTrips, delay: Double(index) * 0.06)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        } header: {
            pastTripsHeader
        }
    }

    private var pastTripsHeader: some View {
        Button {
            HapticFeedback.light()
            withAnimation(OuestTheme.Anim.smooth) {
                showPastTrips.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle")
                    .font(.subheadline)
                Text("Past Trips")
                    .font(OuestTheme.Typography.sectionTitle)
                Text("(\(viewModel.completedTrips.count))")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.7))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .rotationEffect(.degrees(showPastTrips ? 90 : 0))
                    .animation(OuestTheme.Anim.smooth, value: showPastTrips)
            }
            .foregroundStyle(OuestTheme.Colors.textSecondary)
            .padding(.top, OuestTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func tripContextMenu(for trip: Trip) -> some View {
        // Share — opens full share sheet with invite link + QR code
        Button {
            tripToShare = trip
        } label: {
            Label("Share Trip", systemImage: "square.and.arrow.up")
        }

        // Edit
        Button {
            tripToEdit = trip
        } label: {
            Label("Edit Trip", systemImage: "pencil")
        }

        // Status submenu
        Menu {
            ForEach(TripStatus.allCases, id: \.self) { status in
                if status != trip.status {
                    Button {
                        HapticFeedback.medium()
                        Task {
                            withAnimation(OuestTheme.Anim.smooth) {
                                // Optimistic local update for snappy feel
                            }
                            await viewModel.updateTripStatus(trip, to: status)
                        }
                    } label: {
                        Label("Mark as \(status.label)", systemImage: status.icon)
                    }
                }
            }
        } label: {
            Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
        }

        Divider()

        // Delete (destructive)
        Button(role: .destructive) {
            tripToDelete = trip
        } label: {
            Label("Delete Trip", systemImage: "trash")
        }
    }


    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
            Spacer()
        }
        .foregroundStyle(OuestTheme.Colors.textSecondary)
        .padding(.top, OuestTheme.Spacing.sm)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            greetingHeader
                .padding(.horizontal, OuestTheme.Spacing.lg)
                .padding(.top, OuestTheme.Spacing.sm)

            Spacer()

            VStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                    .bouncyAppear(isVisible: cardsAppeared, delay: 0)

                Text("Where to next?")
                    .font(OuestTheme.Typography.screenTitle)
                    .fadeSlideIn(isVisible: cardsAppeared, delay: 0.15)

                Text("Your trips will appear here.\nCreate one to start planning!")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fadeSlideIn(isVisible: cardsAppeared, delay: 0.25)
            }

            OuestButton(title: "Plan a Trip") {
                showCreateTrip = true
            }
            .frame(width: 200)
            .fadeSlideIn(isVisible: cardsAppeared, delay: 0.35)

            Spacer()
        }
        .padding(OuestTheme.Spacing.xxxl)
    }

    // MARK: - Skeleton Loading

    private var skeletonLoadingView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                // Greeting skeleton
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                    SkeletonView(width: 70, height: 14)
                    SkeletonView(width: 200, height: 30)
                    SkeletonView(width: 90, height: 24)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Skeleton featured card
                SkeletonView(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))

                // Skeleton standard cards
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonTripCard()
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthViewModel())
}
