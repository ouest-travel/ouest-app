import MapKit
import SwiftUI

struct ItineraryView: View {
    let trip: Trip
    let canEdit: Bool
    @State private var viewModel: ItineraryViewModel
    @State private var contentAppeared = false
    @State private var viewMode: ViewMode = .list

    /// Confirmation state for the destructive day / activity flows. Lifted
    /// here so a single alert binding can fire from any section header or
    /// swipe action, regardless of which day owns the offending row.
    @State private var dayToDelete: ItineraryDay?
    @State private var activityToDelete: Activity?
    @State private var activityToDeleteDayId: UUID?

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    /// Show calendar toggle whenever there are days to render AND we have
    /// some date anchor to render the calendar against — either the trip's
    /// own date range, or dates on the days themselves (e.g. AI-generated
    /// days set their own dates even if the trip's startDate is nil).
    ///
    /// This used to require trip.startDate AND trip.endDate, which silently
    /// hid the toggle for viewers of trips whose owner never set dates on
    /// the trip row but did generate dated days.
    private var showViewModeToggle: Bool {
        guard !viewModel.days.isEmpty else { return false }
        if trip.startDate != nil && trip.endDate != nil { return true }
        return viewModel.days.contains { $0.date != nil }
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
                    .accessibilityLabel("Trip map")

                    if canEdit {
                        // AI menu — generate or import
                        Menu {
                            if trip.startDate != nil && trip.endDate != nil {
                                Button {
                                    HapticFeedback.light()
                                    viewModel.showAIGenerate = true
                                } label: {
                                    Label("Generate with AI", systemImage: "sparkles")
                                }
                            }
                            Button {
                                HapticFeedback.light()
                                viewModel.showAIImport = true
                            } label: {
                                Label("Import from link or text", systemImage: "wand.and.stars")
                            }
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(OuestTheme.Colors.brand)
                        }
                        .accessibilityLabel("AI tools")
                        .accessibilityHint("Opens a menu to generate or import an itinerary")

                        // Add day button
                        Button {
                            HapticFeedback.light()
                            Task { await viewModel.addDay() }
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                                .foregroundStyle(OuestTheme.Colors.brand)
                        }
                        .accessibilityLabel("Add day")
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
        .sheet(isPresented: $viewModel.showAIGenerate) {
            AIGenerateView(trip: trip, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAIImport) {
            AIImportView(trip: trip, viewModel: viewModel)
        }
    }

    // MARK: - Day List
    // Inset-grouped sections (one per day) so activities can be direct List
    // rows and pick up native .swipeActions(edge: .trailing) for delete.
    // The day header (with its •••-menu Delete Day) lives in the Section's
    // header slot. Mini-map sits as a final styled row inside each section.
    //
    // The AI background banner lives at the root of MainTabView via the
    // shared AIRunCoordinator so it persists across tabs and trips.

    @ViewBuilder
    private var dayListView: some View {
        VStack(spacing: 0) {
            if viewModel.totalEstimatedCost > 0 {
                costSummaryBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.days) { day in
                        daySection(for: day)
                            .id(day.id)
                    }
                    .onMove { from, to in
                        viewModel.moveDays(from: from, to: to)
                    }
                    // Days can't be deleted via swipe (the destructive flow
                    // for whole days lives in the section-header •••-menu
                    // with a confirmation dialog). .deleteDisabled keeps
                    // SwiftUI from creating an implicit minus-circle handle.
                    .deleteDisabled(true)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .onChange(of: viewModel.lastAddedDayId) { _, newValue in
                    guard let id = newValue else { return }
                    withAnimation(OuestTheme.Anim.smooth) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        // Destructive confirmations — one alert apiece, lifted to the parent
        // so we never end up with multiple competing alert bindings.
        .alert(
            "Delete day?",
            isPresented: deleteDayBinding,
            presenting: dayToDelete
        ) { day in
            Button("Cancel", role: .cancel) { dayToDelete = nil }
            Button("Delete", role: .destructive) {
                let d = day
                Task {
                    await viewModel.deleteDay(d)
                    dayToDelete = nil
                }
            }
        } message: { day in
            Text("\"\(day.displayTitle)\" and its \(day.sortedActivities.count) activit\(day.sortedActivities.count == 1 ? "y" : "ies") will be permanently removed.")
        }
        .alert(
            "Delete activity?",
            isPresented: deleteActivityBinding,
            presenting: activityToDelete
        ) { activity in
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
                activityToDeleteDayId = nil
            }
            Button("Delete", role: .destructive) {
                let a = activity
                let dayId = activityToDeleteDayId
                Task {
                    if let dayId {
                        await viewModel.deleteActivity(a, fromDay: dayId)
                    }
                    activityToDelete = nil
                    activityToDeleteDayId = nil
                }
            }
        } message: { activity in
            Text("\"\(activity.title)\" will be permanently removed from this day.")
        }
    }

    private var deleteDayBinding: Binding<Bool> {
        Binding(
            get: { dayToDelete != nil },
            set: { if !$0 { dayToDelete = nil } }
        )
    }

    private var deleteActivityBinding: Binding<Bool> {
        Binding(
            get: { activityToDelete != nil },
            set: {
                if !$0 {
                    activityToDelete = nil
                    activityToDeleteDayId = nil
                }
            }
        )
    }

    // MARK: - Per-day Section

    @ViewBuilder
    private func daySection(for day: ItineraryDay) -> some View {
        Section {
            // 1. Optional notes line (rendered as a styled row).
            if let notes = day.notes, !notes.isEmpty {
                Text(notes)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowSeparator(.hidden)
            }

            // 2. Activities — direct List rows so they get native swipe.
            if day.sortedActivities.isEmpty {
                emptyActivityRow(for: day)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(day.sortedActivities) { activity in
                    ActivityCardView(
                        activity: activity,
                        onEdit: canEdit ? {
                            viewModel.populateFormFromActivity(activity)
                            viewModel.selectedDay = day
                            viewModel.showAddActivity = true
                        } : nil,
                        onDelete: canEdit ? {
                            HapticFeedback.medium()
                            activityToDelete = activity
                            activityToDeleteDayId = day.id
                        } : nil
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if canEdit {
                            Button(role: .destructive) {
                                HapticFeedback.medium()
                                activityToDelete = activity
                                activityToDeleteDayId = day.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }

            // 3. Mini-map as the final row of the section.
            if day.activitiesWithCoordinatesCount > 0 {
                miniMapRow(for: day)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        } header: {
            DayHeaderView(day: day, viewModel: viewModel, canEdit: canEdit) {
                dayToDelete = day
            }
            // The grouped-list header default is uppercased, gray. Reset so
            // our cardTitle styling renders the way DayHeaderView intends.
            .textCase(nil)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func emptyActivityRow(for day: ItineraryDay) -> some View {
        if canEdit {
            Button {
                HapticFeedback.light()
                viewModel.resetActivityForm()
                viewModel.selectedDay = day
                viewModel.showAddActivity = true
            } label: {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(OuestTheme.Colors.brand)
                    Text("Add your first activity")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, OuestTheme.Spacing.sm)
            }
            .buttonStyle(.plain)
        } else {
            Text("No activities planned")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, OuestTheme.Spacing.sm)
        }
    }

    /// Non-interactive map preview at the bottom of each day's section,
    /// rendered as a flush-bleed list row so it slots cleanly inside the
    /// rounded section group.
    private func miniMapRow(for day: ItineraryDay) -> some View {
        let activities = day.sortedActivities.filter(\.hasCoordinates)

        return Map {
            ForEach(activities) { activity in
                if let lat = activity.latitude, let lng = activity.longitude {
                    Annotation(activity.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                        Image(systemName: activity.category.icon)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(activity.category.color)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 120)
        .allowsHitTesting(false)
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
                        Button {
                            HapticFeedback.light()
                            viewModel.showAIGenerate = true
                        } label: {
                            HStack(spacing: OuestTheme.Spacing.sm) {
                                Image(systemName: "sparkles")
                                Text("Generate with AI")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(OuestTheme.Colors.brandGradient)
                            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                            .shadow(OuestTheme.Shadow.md)
                        }
                        .frame(width: 240)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.32)

                        // AI Import — paste TikTok/Instagram/blog link or text
                        Button {
                            HapticFeedback.light()
                            viewModel.showAIImport = true
                        } label: {
                            HStack(spacing: OuestTheme.Spacing.xs) {
                                Image(systemName: "wand.and.stars")
                                Text("Import from link or text")
                            }
                            .font(OuestTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(OuestTheme.Colors.brand)
                        }
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.36)

                        OuestButton(title: "Generate from Trip Dates", style: .secondary) {
                            Task { await viewModel.generateDaysFromTripDates() }
                        }
                        .frame(width: 240)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.42)
                    }

                    OuestButton(title: "Add First Day", style: .secondary) {
                        Task { await viewModel.addDay() }
                    }
                    .frame(width: 200)
                    .fadeSlideIn(isVisible: contentAppeared, delay: tripHasDates ? 0.48 : 0.35)
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
