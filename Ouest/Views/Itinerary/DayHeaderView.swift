import SwiftUI

/// Section header for a single day in the itinerary list. Holds the day's
/// title + total cost on the leading side, and the per-day action buttons
/// (Quick Add, Add Activity, "•••" menu) on the trailing side.
///
/// The "•••" menu is the destructive-action surface: "Reorder Activities"
/// (when there are 2+) and "Delete Day". Both have native iOS confirmation
/// flows wired into the parent ItineraryView.
struct DayHeaderView: View {
    let day: ItineraryDay
    @Bindable var viewModel: ItineraryViewModel
    var canEdit: Bool

    /// Bubbles up to ItineraryView so the confirmation alert lives at the
    /// parent (one alert binding for the whole list, regardless of which
    /// day's header fired it).
    var onRequestDeleteDay: () -> Void

    @State private var showReorderSheet = false

    var body: some View {
        HStack(alignment: .center, spacing: OuestTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.displayTitle)
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)

                if day.totalCost > 0 {
                    Text(formattedCost)
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.success)
                }
            }

            Spacer(minLength: OuestTheme.Spacing.sm)

            if canEdit {
                actions
            }
        }
        // .textCase(nil) reset comes from the call-site in ItineraryView so
        // we don't paint over the brand-typography here unintentionally.
        .padding(.vertical, 4)
        .sheet(isPresented: $showReorderSheet) {
            ReorderActivitiesSheet(day: day, viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Action buttons

    private var actions: some View {
        HStack(spacing: 2) {
            // Quick-add search — magnifying glass
            Button {
                HapticFeedback.light()
                viewModel.searchQuery = ""
                viewModel.searchResults = []
                viewModel.quickAddTargetDay = day
                viewModel.showQuickAdd = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Full add activity — plus.circle.fill
            Button {
                HapticFeedback.light()
                viewModel.resetActivityForm()
                viewModel.selectedDay = day
                viewModel.showAddActivity = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(OuestTheme.Colors.brand)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ••• menu — reorder + destructive Delete Day
            Menu {
                if day.sortedActivities.count >= 2 {
                    Button {
                        showReorderSheet = true
                    } label: {
                        Label("Reorder Activities", systemImage: "arrow.up.arrow.down")
                    }
                    Divider()
                }
                Button(role: .destructive) {
                    onRequestDeleteDay()
                } label: {
                    Label("Delete Day", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Helpers

    private var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: day.totalCost)) ?? ""
    }
}
