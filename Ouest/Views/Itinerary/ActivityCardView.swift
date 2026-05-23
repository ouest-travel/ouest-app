import SwiftUI

struct ActivityCardView: View {
    let activity: Activity
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// When collapsed (default) the card shows a compact summary. Tap toggles
    /// the description + full text — important for viewers who can't open the
    /// edit form to read the rich detail (esp. AI-generated hidden-gem notes).
    @State private var isExpanded = false

    private var hasActions: Bool { onEdit != nil || onDelete != nil }
    private var hasMoreToReveal: Bool {
        (activity.description?.isEmpty == false)
            || (activity.locationName?.isEmpty == false)
            || activity.title.count > 40 // hint of truncation in collapsed state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            // Top row: icon + summary + actions (always visible)
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
                        .lineLimit(isExpanded ? nil : 1)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let time = activity.timeRangeText {
                        Label(time, systemImage: "clock")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    if let location = activity.locationName, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .lineLimit(isExpanded ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let cost = activity.formattedCost {
                        Text(cost)
                            .font(OuestTheme.Typography.micro)
                            .fontWeight(.medium)
                            .foregroundStyle(OuestTheme.Colors.success)
                    }
                }

                Spacer(minLength: 0)

                // Disclosure chevron — shows there's more to read.
                if hasMoreToReveal {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(OuestTheme.Anim.quick, value: isExpanded)
                        .frame(width: 24)
                }

                // Visible actions menu (only when editable)
                if hasActions {
                    Menu {
                        if let onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }

                        if let onDelete {
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Expanded section: full description (and any other detail we want
            // to surface). Indented under the icon column for visual alignment.
            if isExpanded, let description = activity.description, !description.isEmpty {
                Text(description)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 48) // 36 (icon) + 12 (HStack spacing)
                    .padding(.top, OuestTheme.Spacing.xxs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap on the card body toggles the expanded view. The action menu
            // is on its own button so taps there don't trigger this.
            guard hasMoreToReveal else { return }
            HapticFeedback.selection()
            withAnimation(OuestTheme.Anim.smooth) {
                isExpanded.toggle()
            }
        }
        // Keep long-press context menu as a backup
        .contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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
