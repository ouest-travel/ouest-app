import SwiftUI

struct ActivityCardView: View {
    let activity: Activity
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            // Category icon
            Image(systemName: activity.category.icon)
                .font(.body)
                .frame(width: 36, height: 36)
                .background(activity.category.color.opacity(0.12))
                .foregroundStyle(activity.category.color)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))

            // Content
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                Text(activity.title)
                    .font(OuestTheme.Typography.cardTitle)
                    .lineLimit(1)

                if let time = activity.timeRangeText {
                    Label(time, systemImage: "clock")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }

                if let location = activity.locationName, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                if let cost = activity.formattedCost {
                    Text(cost)
                        .font(OuestTheme.Typography.micro)
                        .fontWeight(.medium)
                        .foregroundStyle(OuestTheme.Colors.success)
                }
            }

            Spacer(minLength: 0)

            // Drag handle hint
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ActivityCardView(
        activity: Activity(
            dayId: UUID(),
            title: "Sagrada Familia Tour",
            description: "Guided tour of Gaudi's masterpiece",
            locationName: "Sagrada Familia, Barcelona",
            latitude: 41.4036,
            longitude: 2.1744,
            startTime: "10:00:00",
            endTime: "12:30:00",
            category: .activity,
            costEstimate: 35,
            currency: "EUR",
            sortOrder: 0
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
}
