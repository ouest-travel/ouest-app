import SwiftUI

struct ItineraryView: View {
    let trip: Trip
    @State private var viewModel: ItineraryViewModel
    @State private var contentAppeared = false

    init(trip: Trip) {
        self.trip = trip
        self._viewModel = State(initialValue: ItineraryViewModel(trip: trip))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                skeletonView
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadItinerary() }
                }
            } else if viewModel.days.isEmpty {
                emptyStateView
            } else {
                dayListView
            }
        }
        .navigationTitle("Itinerary")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: OuestTheme.Spacing.md) {
                    // Map button
                    Button {
                        HapticFeedback.light()
                        viewModel.showMap = true
                    } label: {
                        Image(systemName: "map")
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }

                    // Add day button
                    Button {
                        HapticFeedback.light()
                        Task { await viewModel.addDay() }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
        }
        .task {
            await viewModel.loadItinerary()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            contentAppeared = false
            await viewModel.loadItinerary()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .sheet(isPresented: $viewModel.showAddActivity) {
            if let day = viewModel.selectedDay {
                AddActivityView(viewModel: viewModel, day: day)
            }
        }
        .sheet(isPresented: $viewModel.showMap) {
            ItineraryMapView(viewModel: viewModel)
        }
    }

    // MARK: - Day List

    private var dayListView: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.lg) {
                // Total cost summary (if any)
                if viewModel.totalEstimatedCost > 0 {
                    costSummaryBar
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)
                }

                ForEach(Array(viewModel.days.enumerated()), id: \.element.id) { index, day in
                    DayCardView(day: day, viewModel: viewModel)
                        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.06 + 0.05)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteDay(day) }
                            } label: {
                                Label("Delete Day", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Cost Summary Bar

    private var costSummaryBar: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(OuestTheme.Colors.success)
            Text("Estimated Total")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()

            let formatter = NumberFormatter()
            let _ = formatter.numberStyle = .currency
            let _ = formatter.currencyCode = trip.currency ?? "USD"
            Text(formatter.string(from: NSNumber(value: viewModel.totalEstimatedCost)) ?? "$0")
                .font(OuestTheme.Typography.cardTitle)
                .foregroundStyle(OuestTheme.Colors.success)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Empty State

    private var tripHasDates: Bool {
        trip.startDate != nil && trip.endDate != nil
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            VStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                    .bouncyAppear(isVisible: contentAppeared, delay: 0)

                Text("Plan your days")
                    .font(OuestTheme.Typography.screenTitle)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                Text(tripHasDates
                     ? "Generate days from your trip dates\nor add them one by one"
                     : "Add days and fill them with\nactivities, places, and times")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
            }

            VStack(spacing: OuestTheme.Spacing.md) {
                if tripHasDates {
                    OuestButton(title: "Generate from Trip Dates") {
                        Task { await viewModel.generateDaysFromTripDates() }
                    }
                    .frame(width: 240)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.35)
                }

                OuestButton(title: "Add First Day") {
                    Task { await viewModel.addDay() }
                }
                .frame(width: 200)
                .fadeSlideIn(isVisible: contentAppeared, delay: tripHasDates ? 0.42 : 0.35)
            }

            Spacer()
        }
        .padding(OuestTheme.Spacing.xxxl)
    }

    // MARK: - Skeleton Loading

    private var skeletonView: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                        SkeletonView(width: 120, height: 16)
                        SkeletonView(height: 60)
                        SkeletonView(height: 60)
                    }
                    .padding(OuestTheme.Spacing.lg)
                    .background(OuestTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                    .shadow(OuestTheme.Shadow.md)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.sm)
        }
    }
}

#Preview {
    NavigationStack {
        ItineraryView(trip: Trip(
            id: UUID(), createdBy: UUID(),
            title: "Summer in Barcelona", destination: "Barcelona, Spain",
            startDate: Date(), endDate: Date().addingTimeInterval(7 * 86400),
            status: .planning, isPublic: false,
            createdAt: Date(), updatedAt: Date()
        ))
    }
}
