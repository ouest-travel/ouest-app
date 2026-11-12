import SwiftUI

/// A flowing date range picker: tap "Start" or "End" label to toggle which date
/// the inline graphical calendar is editing. Automatically advances to end date
/// after start is picked.
struct TripDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    enum Focus { case start, end }
    @State private var focus: Focus = .start

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
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .onChange(of: startDate) { _, newStart in
                        // Ensure end >= start
                        if endDate < newStart {
                            endDate = newStart
                        }
                        // Auto-advance to end date after picking start
                        withAnimation(OuestTheme.Anim.quick) { focus = .end }
                    }
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
        }
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
