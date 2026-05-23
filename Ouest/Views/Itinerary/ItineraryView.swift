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
        .sheet(isPresented: $viewModel.showAIGenerate) {
            AIGenerateView(trip: trip, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAIImport) {
            AIImportView(trip: trip, viewModel: viewModel)
        }
        // Floating banner shown when AI is running in the background (sheet was
        // minimized). Tap restores the matching sheet.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowAIBanner {
                aiBackgroundBanner
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, OuestTheme.Spacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(OuestTheme.Anim.smooth, value: shouldShowAIBanner)
    }

    // MARK: - Background AI Banner

    /// Show the banner whenever AI work is happening OR has just failed while
    /// the user was elsewhere — but only when neither AI sheet is open (the
    /// sheet handles its own loading + alert when visible).
    private var shouldShowAIBanner: Bool {
        guard !viewModel.showAIGenerate, !viewModel.showAIImport else { return false }
        return viewModel.isGeneratingAI || viewModel.aiError != nil
    }

    /// Banner has two visual modes:
    /// 1. Loading — brand gradient with spinner ("Building your itinerary…")
    /// 2. Error  — red with warning icon + dismiss button ("Couldn't generate…")
    ///
    /// In both modes, tapping the body re-opens the matching AI sheet so the
    /// user sees the full progress or the error alert.
    @ViewBuilder
    private var aiBackgroundBanner: some View {
        if viewModel.isGeneratingAI {
            aiLoadingBanner
        } else if let error = viewModel.aiError {
            aiErrorBanner(error)
        }
    }

    private var aiLoadingBanner: some View {
        Button(action: reopenLastAISheet) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(.white)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Building your itinerary…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Tap to view progress")
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(OuestTheme.Colors.brandGradient)
            .clipShape(Capsule())
            .shadow(OuestTheme.Shadow.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI is building your itinerary. Tap to view progress.")
    }

    private func aiErrorBanner(_ message: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            // Main tap target → re-open the sheet so the user sees the alert
            // with the full error message and can retry.
            Button(action: reopenLastAISheet) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Couldn't generate itinerary")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(message)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text("Retry")
                        .font(OuestTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Secondary affordance to clear the error without re-opening.
            Button {
                HapticFeedback.light()
                withAnimation(OuestTheme.Anim.smooth) {
                    viewModel.aiError = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(OuestTheme.Colors.error)
        .clipShape(Capsule())
        .shadow(OuestTheme.Shadow.md)
        .accessibilityElement(children: .contain)
    }

    /// Re-open whichever AI sheet kicked off the most recent run.
    private func reopenLastAISheet() {
        HapticFeedback.light()
        switch viewModel.lastAIMode {
        case .importing:
            viewModel.showAIImport = true
        case .generate, nil:
            viewModel.showAIGenerate = true
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
