import SwiftUI

struct ItineraryView: View {
    let trip: Trip
    let canEdit: Bool
    @State private var viewModel: ItineraryViewModel
    @State private var contentAppeared = false
    @State private var viewMode: ViewMode = .list

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    /// Show calendar toggle only when trip has dates and days exist
    private var showViewModeToggle: Bool {
        trip.startDate != nil && trip.endDate != nil && !viewModel.days.isEmpty
    }

    init(trip: Trip, canEdit: Bool = true) {
        self.trip = trip
        self.canEdit = canEdit
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
                VStack(spacing: 0) {
                    // View mode toggle (List / Calendar)
                    if showViewModeToggle {
                        Picker("View", selection: $viewMode) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, OuestTheme.Spacing.lg)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                    }

                    // Content based on view mode
                    if viewMode == .calendar && showViewModeToggle {
                        ItineraryCalendarView(
                            trip: trip,
                            days: viewModel.days,
                            viewModel: viewModel,
                            canEdit: canEdit
                        )
                    } else {
                        dayListView
                    }
                }
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

                    if canEdit {
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
        .sheet(isPresented: $viewModel.showQuickAdd) {
            if let day = viewModel.quickAddTargetDay {
                QuickAddActivityView(viewModel: viewModel, day: day)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $viewModel.showMap) {
            ItineraryMapView(viewModel: viewModel)
        }
    }

    // MARK: - Day List

    @ViewBuilder
    private var dayListView: some View {
        List {
            Section {
                ForEach(viewModel.days) { day in
                    DayCardView(day: day, viewModel: viewModel, canEdit: canEdit)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onMove { from, to in
                    viewModel.moveDays(from: from, to: to)
                }
                .deleteDisabled(true)
            } header: {
                if viewModel.totalEstimatedCost > 0 {
                    costSummaryBar
                        .textCase(nil)
                        .padding(.bottom, 8)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(canEdit ? .active : .inactive))
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

                Text(canEdit ? "Plan your days" : "No itinerary yet")
                    .font(OuestTheme.Typography.screenTitle)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                Text(canEdit
                     ? (tripHasDates
                        ? "Generate days from your trip dates\nor add them one by one"
                        : "Add days and fill them with\nactivities, places, and times")
                     : "The trip owner hasn't added\nan itinerary yet")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
            }

            if canEdit {
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
