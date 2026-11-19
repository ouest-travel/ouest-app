import SwiftUI

/// A flowing date range picker: tap "Start" or "End" label to toggle which date
/// the inline graphical calendar is editing. Automatically advances to end date
/// after start is picked. Picking a start moves the end with it so the trip
/// keeps its length and the end calendar opens on the same month; otherwise
/// swiping to "August" from a stale end month lands a year late.
struct TripDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    enum Focus { case start, end }
    @State private var focus: Focus = .start

    /// Trips longer than this get a caution under the calendar. It never blocks saving.
    private static let longTripDays = 60

    private var tripLengthDays: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
    }

    /// Binding for the start calendar. Only the user's taps go through here,
    /// so loading an existing trip into `startDate` leaves the end alone.
    private var startSelection: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newStart in
                let length = max(0, endDate.timeIntervalSince(startDate))
                endDate = newStart.addingTimeInterval(length)
                startDate = newStart
                withAnimation(OuestTheme.Anim.quick) { focus = .end }
            }
        )
    }

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            // Date labels
            HStack(spacing: OuestTheme.Spacing.md) {
                dateLabel(
                    title: "Start",
                    date: startDate,
                    isActive: focus == .start
                ) {
                    withAnimation(OuestTheme.Anim.quick) { focus = .start }
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)

                dateLabel(
                    title: "End",
                    date: endDate,
                    isActive: focus == .end
                ) {
                    withAnimation(OuestTheme.Anim.quick) { focus = .end }
                }
            }

            // Single graphical calendar
            Group {
                if focus == .start {
                    DatePicker(
                        "Start Date",
                        selection: startSelection,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                } else {
                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }
            }
            .tint(OuestTheme.Colors.brand)

            if tripLengthDays > Self.longTripDays {
                Label("This trip is \(tripLengthDays) days long", systemImage: "exclamationmark.triangle")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.warningInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .animation(OuestTheme.Anim.quick, value: tripLengthDays > Self.longTripDays)
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    private func dateLabel(title: String, date: Date, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text(title)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(isActive ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? OuestTheme.Colors.brand : OuestTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OuestTheme.Spacing.sm)
            .background(
                isActive
                ? OuestTheme.Colors.brand.opacity(0.08)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
        }
        .buttonStyle(.plain)
    }
}
