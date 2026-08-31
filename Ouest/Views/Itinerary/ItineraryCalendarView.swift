import SwiftUI

/// Calendar grid view for the itinerary — shows trip days on a month grid
/// with activity indicators, and a detail panel for the selected day.
struct ItineraryCalendarView: View {

    let trip: Trip
    let days: [ItineraryDay]
    @Bindable var viewModel: ItineraryViewModel
    let canEdit: Bool

    @State private var displayedMonth: Date
    @State private var selectedDate: Date?
    @State private var appeared = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    init(trip: Trip, days: [ItineraryDay], viewModel: ItineraryViewModel, canEdit: Bool) {
        self.trip = trip
        self.days = days
        self.viewModel = viewModel
        self.canEdit = canEdit

        // Start on the month of the trip's start date (or today)
        let startDate = trip.startDate ?? Date()
        self._displayedMonth = State(initialValue: startDate)

        // Auto-select trip start date or today
        if let tripStart = trip.startDate {
            self._selectedDate = State(initialValue: tripStart)
        }
    }

    /// Map dates to their ItineraryDay for quick lookup
    private var daysByDate: [String: ItineraryDay] {
        var map: [String: ItineraryDay] = [:]
        for day in days {
            if let date = day.date {
                map[dateKey(date)] = day
            }
        }
        return map
    }

    /// The selected ItineraryDay (if any)
    private var selectedDay: ItineraryDay? {
        guard let date = selectedDate else { return nil }
        return daysByDate[dateKey(date)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Month navigation header
                monthHeader
                    .padding(.horizontal, OuestTheme.Spacing.lg)
                    .padding(.bottom, OuestTheme.Spacing.md)

                // Weekday labels
                weekdayRow
                    .padding(.horizontal, OuestTheme.Spacing.sm)

                // Calendar grid
                calendarGrid
                    .padding(.horizontal, OuestTheme.Spacing.sm)
                    .padding(.bottom, OuestTheme.Spacing.xl)

                // Selected day detail panel
                if let day = selectedDay {
                    selectedDayPanel(day)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else if let date = selectedDate, isTripDate(date) {
                    // Trip date with no itinerary day generated yet
                    emptyDayPanel(for: date)
                }
            }
            .padding(.top, OuestTheme.Spacing.sm)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
        .onAppear {
            withAnimation(OuestTheme.Anim.smooth) {
                appeared = true
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(OuestTheme.Anim.quick) {
                    moveMonth(by: -1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(OuestTheme.Typography.sectionTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)

            Spacer()

            Button {
                withAnimation(OuestTheme.Anim.quick) {
                    moveMonth(by: 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Weekday Row

    private var weekdayRow: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(height: 28)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let dates = datesForMonth(displayedMonth)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(dates, id: \.self) { date in
                if let date {
                    dayCell(for: date)
                } else {
                    // Empty cell for padding
                    Color.clear.frame(height: 52)
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(for date: Date) -> some View {
        let isTrip = isTripDate(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)
        let itineraryDay = daysByDate[dateKey(date)]
        let activityColors = itineraryDay?.sortedActivities.prefix(3).map(\.category.color) ?? []
        let dayNum = calendar.component(.day, from: date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            HapticFeedback.light()
            withAnimation(OuestTheme.Anim.quick) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    // Selection / trip highlight
                    if isSelected {
                        Circle()
                            .fill(OuestTheme.Colors.brand)
                            .frame(width: 36, height: 36)
                    } else if isTrip {
                        Circle()
                            .fill(OuestTheme.Colors.brand.opacity(0.15))
                            .frame(width: 36, height: 36)
                    }

                    // Today ring
                    if isToday && !isSelected {
                        Circle()
                            .stroke(OuestTheme.Colors.brand, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    // Day number
                    Text("\(dayNum)")
                        .font(.system(size: 15, weight: isTrip ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ? .white :
                            isTrip ? OuestTheme.Colors.textPrimary :
                            isCurrentMonth ? OuestTheme.Colors.textSecondary :
                            OuestTheme.Colors.textSecondary.opacity(0.3)
                        )
                }

                // Activity indicator dots
                HStack(spacing: 3) {
                    ForEach(Array(activityColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
                .opacity(isSelected ? 0.8 : 1)
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Day Panel

    private func selectedDayPanel(_ day: ItineraryDay) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.lg) {
            // Divider
            Rectangle()
                .fill(OuestTheme.Colors.brand.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, OuestTheme.Spacing.lg)

            // Day header
            HStack {
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                    Text(day.displayTitle)
                        .font(OuestTheme.Typography.sectionTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    if day.totalCost > 0 {
                        let formatter = NumberFormatter()
                        let _ = formatter.numberStyle = .currency
                        let _ = formatter.currencyCode = trip.currency ?? "USD"
                        if let costText = formatter.string(from: NSNumber(value: day.totalCost)) {
                            Text(costText)
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(OuestTheme.Colors.success)
                        }
                    }
                }

                Spacer()

                if canEdit {
                    Button {
                        HapticFeedback.light()
                        viewModel.resetActivityForm()
                        viewModel.selectedDay = day
                        viewModel.showAddActivity = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(OuestTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)

            // Notes
            if let notes = day.notes, !notes.isEmpty {
                Text(notes)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .padding(.horizontal, OuestTheme.Spacing.lg)
            }

            // Activities
            if day.sortedActivities.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "sun.horizon")
                            .font(.title2)
                            .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.5))
                        Text("No activities planned")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        if canEdit {
                            Text("Tap + to add one")
                                .font(OuestTheme.Typography.micro)
                                .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.6))
                        }
                    }
                    .padding(.vertical, OuestTheme.Spacing.xxl)
                    Spacer()
                }
            } else {
                VStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(day.sortedActivities) { activity in
                        let editAction: (() -> Void)? = canEdit ? {
                            viewModel.populateFormFromActivity(activity)
                            viewModel.selectedDay = day
                            viewModel.showAddActivity = true
                        } : nil
                        let deleteAction: (() -> Void)? = canEdit ? {
                            Task { await viewModel.deleteActivity(activity, fromDay: day.id) }
                        } : nil

                        ActivityCardView(activity: activity, onEdit: editAction, onDelete: deleteAction)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)
            }
        }
        .id(day.id) // Force view recreation for smooth transitions
    }

    // MARK: - Empty Day Panel (trip date, no ItineraryDay yet)

    private func emptyDayPanel(for date: Date) -> some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Rectangle()
                .fill(OuestTheme.Colors.brand.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, OuestTheme.Spacing.lg)

            HStack {
                Text(date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(OuestTheme.Typography.sectionTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)

            VStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.5))
                Text("No itinerary for this day")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
            .padding(.vertical, OuestTheme.Spacing.xxl)
        }
    }

    // MARK: - Helpers

    /// Format date to a consistent string key for dictionary lookup
    private func dateKey(_ date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
    }

    /// Check if a date falls within the trip date range
    private func isTripDate(_ date: Date) -> Bool {
        guard let start = trip.startDate, let end = trip.endDate else { return false }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dateDay = calendar.startOfDay(for: date)
        return dateDay >= startDay && dateDay <= endDay
    }

    /// Get month/year display string
    private func monthYearString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    /// Move displayed month forward/back
    private func moveMonth(by offset: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    /// Generate all dates to display for a given month (including leading/trailing padding)
    private func datesForMonth(_ monthDate: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1 = Sunday
        let leadingEmpty = firstWeekday - 1

        var dates: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                dates.append(date)
            }
        }

        // Pad trailing to complete the last row
        while dates.count % 7 != 0 {
            dates.append(nil)
        }

        return dates
    }
}

// MARK: - Preview

#Preview {
    let trip = Trip(
        id: UUID(), createdBy: UUID(),
        title: "Barcelona", destination: "Barcelona",
        startDate: Date(), endDate: Date().addingTimeInterval(7 * 86400),
        status: .planning, isPublic: false,
        createdAt: Date(), updatedAt: Date()
    )
    NavigationStack {
        ItineraryCalendarView(
            trip: trip,
            days: [],
            viewModel: ItineraryViewModel(trip: trip),
            canEdit: true
        )
        .navigationTitle("Itinerary")
    }
}
