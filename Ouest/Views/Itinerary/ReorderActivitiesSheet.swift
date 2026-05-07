import SwiftUI

/// Drag-to-reorder sheet for activities within a single day.
///
/// Uses SwiftUI's native `List` + `.onMove` for reliable drag interaction.
/// Persists changes via `ItineraryViewModel.moveActivities()`.
struct ReorderActivitiesSheet: View {

    let day: ItineraryDay
    @Bindable var viewModel: ItineraryViewModel
    @Environment(\.dismiss) private var dismiss

    private var activities: [Activity] {
        guard let dayIndex = viewModel.days.firstIndex(where: { $0.id == day.id }) else { return [] }
        return viewModel.days[dayIndex].sortedActivities
    }

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
            .navigationTitle(day.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.brand)
                        .fontWeight(.semibold)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }

    // MARK: - Activity List

    private var activityList: some View {
        List {
            Section {
                ForEach(activities) { activity in
                    activityRow(activity)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onMove { from, to in
                    viewModel.moveActivities(inDay: day.id, from: from, to: to)
                }
            } header: {
                Text("Drag to reorder")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .textCase(nil)
                    .padding(.horizontal, 4)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            // Category icon
            Image(systemName: activity.category.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(activity.category.color)
                .clipShape(Circle())

            // Title + time
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let timeRange = activity.timeRangeText {
                    Text(timeRange)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                } else if let location = activity.locationName {
                    Text(location)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .shadow(OuestTheme.Shadow.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: OuestTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(OuestTheme.Colors.textSecondary.opacity(0.4))
            Text("No activities to reorder")
                .font(OuestTheme.Typography.cardTitle)
            Text("Add some activities first.")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ReorderActivitiesSheet(
        day: ItineraryDay(
            tripId: UUID(), dayNumber: 1, date: Date(),
            activities: [
                Activity(dayId: UUID(), title: "Sagrada Familia", category: .activity, sortOrder: 0),
                Activity(dayId: UUID(), title: "La Boqueria Market", startTime: "12:00:00", category: .food, sortOrder: 1),
                Activity(dayId: UUID(), title: "Park Güell", category: .activity, sortOrder: 2)
            ]
        ),
        viewModel: ItineraryViewModel(trip: Trip(
            id: UUID(), createdBy: UUID(), title: "Barcelona", destination: "Barcelona",
            status: .planning, isPublic: false, createdAt: Date(), updatedAt: Date()
        ))
    )
}
