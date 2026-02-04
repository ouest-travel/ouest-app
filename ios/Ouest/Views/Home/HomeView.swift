import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var demoModeManager: DemoModeManager

    @State private var trips: [Trip] = []
    @State private var isLoading = true
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Header
                        headerView

                        // Trips List
                        if isLoading {
                            loadingView
                        } else if trips.isEmpty {
                            emptyStateView
                        } else {
                            tripsListView
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        OuestFAB(icon: "plus") {
                            showCreateTrip = true
                        }
                        .padding(.trailing, OuestTheme.Spacing.md)
                        .padding(.bottom, OuestTheme.Spacing.md)
                    }
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                CreateTripSheet()
            }
            .onAppear {
                loadTrips()
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
            Text("Your Trips")
                .font(OuestTheme.Fonts.title)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Plan, track, and share your adventures")
                .font(OuestTheme.Fonts.subheadline)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, OuestTheme.Spacing.md)
    }

    private var loadingView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.large)
                    .fill(OuestTheme.Colors.inputBackground)
                    .frame(height: 160)
                    .shimmer()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 64))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No trips yet")
                .font(OuestTheme.Fonts.title3)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Start planning your first adventure!")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            OuestButton("Create Trip", icon: "plus") {
                showCreateTrip = true
            }
            .padding(.top, OuestTheme.Spacing.sm)
        }
        .padding(.vertical, OuestTheme.Spacing.xxl)
    }

    private var tripsListView: some View {
        LazyVStack(spacing: OuestTheme.Spacing.md) {
            ForEach(trips) { trip in
                NavigationLink(destination: BudgetOverviewView(trip: trip)) {
                    ActiveTripCard(trip: trip)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Data Loading

    private func loadTrips() {
        if demoModeManager.isDemoMode {
            trips = DemoModeManager.demoTrips
            isLoading = false
            return
        }

        // TODO: Load from Supabase
        Task {
            // Simulate loading
            try? await Task.sleep(nanoseconds: 500_000_000)
            trips = []
            isLoading = false
        }
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

// MARK: - Placeholder Sheets

struct CreateTripSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Text("Create Trip Form - Coming Soon")
                .navigationTitle("New Trip")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
