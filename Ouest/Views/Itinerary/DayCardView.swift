import SwiftUI
import MapKit

struct DayCardView: View {
    let day: ItineraryDay
    @Bindable var viewModel: ItineraryViewModel
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            // Day Header
            dayHeader

            if isExpanded {
                // Notes
                if let notes = day.notes, !notes.isEmpty {
                    Text(notes)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .padding(.horizontal, OuestTheme.Spacing.sm)
                }

                // Activities
                if day.sortedActivities.isEmpty {
                    emptyActivitiesHint
                } else {
                    activitiesList
                }

                // Mini map preview
                if day.activitiesWithCoordinatesCount > 0 {
                    miniMapPreview
                }
            }
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                Text(day.displayTitle)
                    .font(OuestTheme.Typography.sectionTitle)

                if day.totalCost > 0 {
                    let formatter = NumberFormatter()
                    let _ = formatter.numberStyle = .currency
                    let _ = formatter.currencyCode = "USD"
                    if let costText = formatter.string(from: NSNumber(value: day.totalCost)) {
                        Text(costText)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.success)
                    }
                }
            }

            Spacer()

            // Add activity button
            Button {
                HapticFeedback.light()
                viewModel.resetActivityForm()
                viewModel.selectedDay = day
                viewModel.showAddActivity = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(OuestTheme.Colors.brand)
            }

            // Expand/collapse
            Button {
                withAnimation(OuestTheme.Anim.quick) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
    }

    // MARK: - Activities List

    private var activitiesList: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(day.sortedActivities) { activity in
                ActivityCardView(
                    activity: activity,
                    onEdit: {
                        viewModel.populateFormFromActivity(activity)
                        viewModel.selectedDay = day
                        viewModel.showAddActivity = true
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteActivity(activity, fromDay: day.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty Hint

    private var emptyActivitiesHint: some View {
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
            .frame(maxWidth: .infinity)
            .padding(OuestTheme.Spacing.lg)
            .background(OuestTheme.Colors.surfaceSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mini Map Preview

    private var miniMapPreview: some View {
        let activities = day.sortedActivities.filter(\.hasCoordinates)
        let coordinates = activities.compactMap { act -> CLLocationCoordinate2D? in
            guard let lat = act.latitude, let lng = act.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

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
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .allowsHitTesting(false) // Non-interactive preview
    }
}

#Preview {
    let day = ItineraryDay(
        tripId: UUID(),
        dayNumber: 1,
        date: Date(),
        title: nil,
        activities: [
            Activity(dayId: UUID(), title: "Breakfast at La Boqueria", category: .food, sortOrder: 0),
            Activity(dayId: UUID(), title: "Sagrada Familia", locationName: "Barcelona", startTime: "10:00:00", endTime: "12:00:00", category: .activity, costEstimate: 35, currency: "EUR", sortOrder: 1),
        ]
    )

    DayCardView(
        day: day,
        viewModel: ItineraryViewModel(trip: Trip(
            id: UUID(), createdBy: UUID(), title: "Barcelona", destination: "Barcelona, Spain",
            status: .planning, isPublic: false, createdAt: Date(), updatedAt: Date()
        ))
    )
    .padding()
}
