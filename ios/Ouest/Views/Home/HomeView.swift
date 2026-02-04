import SwiftUI

struct HomeView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - ViewModel

    @StateObject private var viewModel: HomeViewModel

    // MARK: - Local State

    @State private var showCreateTrip = false

    // MARK: - Initialization

    init(repositories: RepositoryProvider? = nil, userId: String? = nil) {
        let repos = repositories ?? RepositoryProvider()
        let id = userId ?? "demo-user"
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            tripRepository: repos.tripRepository,
            userId: id
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Header with greeting
                        headerView

                        // Filter pills
                        filterView

                        // Trips List
                        if viewModel.isLoading {
                            loadingView
                        } else if !viewModel.hasTrips {
                            emptyStateView
                        } else {
                            tripsListView
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.refresh()
                }

                // FAB
                fabView
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTrips()
                viewModel.startObserving()
            }
            .onDisappear {
                viewModel.stopObserving()
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text(greeting)
                .font(OuestTheme.Fonts.title)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Plan, track, and share your adventures")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, OuestTheme.Spacing.md)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.authViewModel.profile?.displayName ?? "there"

        switch hour {
        case 5..<12:
            return "Good morning, \(name)"
        case 12..<17:
            return "Good afternoon, \(name)"
        default:
            return "Good evening, \(name)"
        }
    }

    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                ForEach(TripFilter.allCases, id: \.self) { filter in
                    OuestPillButton(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation(OuestTheme.Animation.spring) {
                            viewModel.selectedFilter = filter
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
                    .frame(height: 180)
                    .shimmer()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 72))
                .foregroundStyle(OuestTheme.Gradients.primary)

            Text("No trips yet")
                .font(OuestTheme.Fonts.title3)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Start planning your first adventure!")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            OuestButton("Create Trip", style: .accent, icon: "plus") {
                showCreateTrip = true
            }
            .padding(.top, OuestTheme.Spacing.sm)
        }
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var tripsListView: some View {
        LazyVStack(spacing: OuestTheme.Spacing.md) {
            ForEach(viewModel.filteredTrips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip, repositories: appState.repositories)
                } label: {
                    ActiveTripCard(trip: trip)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var fabView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                OuestFAB(icon: "plus", style: .accent) {
                    showCreateTrip = true
                }
                .padding(.trailing, OuestTheme.Spacing.lg)
                .padding(.bottom, OuestTheme.Spacing.lg)
            }
        }
    }
}

// MARK: - Create Trip Sheet

struct CreateTripSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var budget: Decimal?
    @State private var currency = "USD"
    @State private var isPublic = false
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    TextField("Trip Name", text: $name)
                    TextField("Destination", text: $destination)
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                Section("Budget") {
                    HStack {
                        TextField("Budget", value: $budget, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Currency", selection: $currency) {
                            ForEach(CurrencyFormatter.supportedCurrencies) { curr in
                                Text(curr.code).tag(curr.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    Toggle("Share with community", isOn: $isPublic)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createTrip() }
                    }
                    .disabled(name.isEmpty || destination.isEmpty || isCreating)
                }
            }
        }
    }

    private func createTrip() async {
        isCreating = true

        let request = CreateTripRequest(
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            budget: budget,
            currency: currency,
            createdBy: "", // Will be set by repository
            isPublic: isPublic,
            votingEnabled: false,
            coverImage: nil,
            description: nil,
            status: .planning
        )

        do {
            _ = try await viewModel.createTrip(request)
            dismiss()
        } catch {
            // Handle error
        }

        isCreating = false
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Preview

#Preview {
    HomeView(repositories: RepositoryProvider(isDemoMode: true))
        .environmentObject(AppState(isDemoMode: true))
}
