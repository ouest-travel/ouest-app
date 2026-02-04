import SwiftUI

// MARK: - Community Filter

enum CommunityFilter: String, CaseIterable {
    case all = "All"
    case trending = "Trending"
    case nearby = "Nearby"
    case recent = "Recent"
}

// MARK: - Community View

struct CommunityView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: CommunityViewModel

    @State private var searchText = ""
    @State private var selectedFilter: CommunityFilter = .all
    @State private var selectedTrip: Trip?

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
                        headerView

                        // Search Bar
                        searchBar

                        // Filter Pills
                        filterPills

                        // Featured Section
                        if !viewModel.publicTrips.isEmpty && selectedFilter == .all && searchText.isEmpty {
                            featuredSection
                        }

                        // Content
                        if viewModel.isLoading {
                            loadingView
                        } else if filteredTrips.isEmpty {
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
            .navigationDestination(item: $selectedTrip) { trip in
                PublicTripDetailView(trip: trip, repositories: appState.repositories)
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredTrips: [Trip] {
        var trips = viewModel.publicTrips

        // Search filter
        if !searchText.isEmpty {
            trips = trips.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.destination.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Category filter
        switch selectedFilter {
        case .all:
            break
        case .trending:
            // Sort by some popularity metric (using created date as proxy for now)
            trips = trips.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
        case .nearby:
            // TODO: Filter by location
            break
        case .recent:
            trips = trips.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
        }

        return trips
    }

    // MARK: - Subviews

    private var headerView: some View {
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
    }

    private var searchBar: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(OuestTheme.Colors.textTertiary)

            TextField("Search destinations...", text: $searchText)
                .font(OuestTheme.Fonts.body)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(OuestTheme.Colors.textTertiary)
                }
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                ForEach(CommunityFilter.allCases, id: \.self) { filter in
                    OuestPillButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(OuestTheme.Animation.spring) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack {
                Text("Featured")
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)

                Spacer()

                Button("See All") {
                    selectedFilter = .trending
                }
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.md) {
                    ForEach(viewModel.publicTrips.prefix(5)) { trip in
                        FeaturedTripCard(trip: trip) {
                            selectedTrip = trip
                        }
                    }
                }
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
            Image(systemName: searchText.isEmpty ? "globe" : "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text(searchText.isEmpty ? "No public trips yet" : "No results found")
                .font(OuestTheme.Fonts.title3)
                .foregroundColor(OuestTheme.Colors.text)

            Text(searchText.isEmpty ? "Be the first to share your adventure!" : "Try a different search term")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var publicTripsListView: some View {
        LazyVStack(spacing: OuestTheme.Spacing.md) {
            ForEach(filteredTrips) { trip in
                CommunityTripCard(trip: trip, onSave: {
                    Task {
                        await viewModel.saveTrip(trip)
                    }
                }, onTap: {
                    selectedTrip = trip
                })
            }
        }
    }
}

// MARK: - Featured Trip Card

struct FeaturedTripCard: View {
    let trip: Trip
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.destinationEmoji)
                            .font(.system(size: 28))

                        Text(trip.destination)
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(OuestTheme.Spacing.sm)
                }
                .frame(width: 160, height: 100)
                .cornerRadius(OuestTheme.CornerRadius.medium)

                // Title
                Text(trip.name)
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.text)
                    .lineLimit(1)
                    .padding(.top, OuestTheme.Spacing.xs)
            }
            .frame(width: 160)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var gradientColors: [Color] {
        let destination = trip.destination.lowercased()
        if destination.contains("japan") || destination.contains("tokyo") {
            return [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]
        } else if destination.contains("france") || destination.contains("paris") {
            return [Color(hex: "667eea"), Color(hex: "764ba2")]
        } else {
            return [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo]
        }
    }
}

// MARK: - Community Trip Card

struct CommunityTripCard: View {
    let trip: Trip
    let onSave: () -> Void
    let onTap: () -> Void

    @State private var isSaved = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo],
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
                        withAnimation(OuestTheme.Animation.spring) {
                            isSaved.toggle()
                        }
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
                        Text(trip.formattedDateRange)
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
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Public Trip Detail View

struct PublicTripDetailView: View {
    let trip: Trip
    let repositories: RepositoryProvider

    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: OuestTheme.Spacing.lg) {
                    // Header
                    tripHeader

                    // Description
                    if let description = trip.description, !description.isEmpty {
                        descriptionSection(description)
                    }

                    // Trip Info
                    tripInfoSection

                    // Itinerary Preview
                    itineraryPreviewSection

                    // Save Button
                    saveButton
                }
                .padding(OuestTheme.Spacing.md)
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tripHeader: some View {
        OuestGradientCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                HStack {
                    Text(trip.destinationEmoji)
                        .font(.system(size: 48))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.destination)
                            .font(OuestTheme.Fonts.title2)
                            .foregroundColor(.white)

                        Text(trip.formattedDateRange)
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                // Creator
                HStack(spacing: OuestTheme.Spacing.sm) {
                    OuestAvatar(trip.creator, size: .medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shared by")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text(trip.creator?.displayNameOrEmail ?? "Unknown")
                            .font(OuestTheme.Fonts.headline)
                            .foregroundColor(.white)
                    }

                    Spacer()
                }
            }
        }
    }

    private func descriptionSection(_ description: String) -> some View {
        OuestCard {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text("About this trip")
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(description)
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
        }
    }

    private var tripInfoSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OuestTheme.Spacing.sm) {
            InfoTile(icon: "calendar", title: "Duration", value: "\(trip.durationDays ?? 0) days")
            InfoTile(icon: "creditcard", title: "Budget", value: trip.budget.map { CurrencyFormatter.format(amount: $0, currency: trip.currency) } ?? "Not set")
        }
    }

    private var itineraryPreviewSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            Text("Itinerary Preview")
                .font(OuestTheme.Fonts.headline)
                .foregroundColor(OuestTheme.Colors.text)

            OuestCard {
                VStack(spacing: OuestTheme.Spacing.md) {
                    ForEach(1...3, id: \.self) { day in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(OuestTheme.Gradients.primary)
                                    .frame(width: 32, height: 32)

                                Text("\(day)")
                                    .font(OuestTheme.Fonts.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(day)")
                                    .font(OuestTheme.Fonts.headline)
                                    .foregroundColor(OuestTheme.Colors.text)

                                Text("Activities planned...")
                                    .font(OuestTheme.Fonts.caption)
                                    .foregroundColor(OuestTheme.Colors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(OuestTheme.Colors.textTertiary)
                        }

                        if day < 3 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        OuestButton(
            "Save Itinerary",
            style: .primary,
            icon: "bookmark.fill",
            isLoading: isSaving,
            isFullWidth: true
        ) {
            // TODO: Save itinerary
        }
    }
}

// MARK: - Info Tile

struct InfoTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        OuestCard {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(OuestTheme.Colors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textSecondary)

                    Text(value)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(OuestTheme.Colors.text)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    CommunityView(repositories: RepositoryProvider(isDemoMode: true))
        .environmentObject(AppState(isDemoMode: true))
}
