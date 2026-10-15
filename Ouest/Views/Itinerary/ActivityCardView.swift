import SwiftUI

struct ActivityCardView: View {
    let activity: Activity
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    /// Expand inline to show the activity description. For viewers (no onEdit
    /// callback) this is the only way to read the full notes — tap toggles it.
    /// For editors, tapping the row goes straight to Edit instead, since the
    /// description is visible in that sheet too.
    @State private var isExpanded = false

    private var canEdit: Bool { onEdit != nil }
    private var canDelete: Bool { onDelete != nil }
    private var hasMoreToReveal: Bool {
        (activity.description?.isEmpty == false)
            || (activity.locationName?.isEmpty == false)
            || activity.title.count > 40
    }

    var body: some View {
        // Primary interaction model:
        // - Tap → opens Edit (editors) or expands the description (viewers).
        // - Long-press → context menu with Edit + Delete (iOS-standard
        //   destructive-action affordance).
        //
        // A custom swipe-to-delete reveal was attempted but the layered
        // layout doesn't render reliably inside the nested
        // VStack-inside-List-row context this view lives in. Proper fix
        // (follow-up): lift activities to first-class List rows so native
        // .swipeActions(edge: .trailing) works.
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.md) {
                // Category icon
                Image(systemName: activity.category.icon)
                    .font(.body)
                    .frame(width: 36, height: 36)
                    .background(activity.category.color.opacity(0.12))
                    .foregroundStyle(activity.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))

                // Text content
                VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                    Text(activity.title)
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(.primary)
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

                // For viewers: chevron indicates the row expands to reveal the
                // description inline. Editors don't see it (tap goes to Edit,
                // which already shows the description in the form).
                if hasMoreToReveal && !canEdit {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(OuestTheme.Anim.quick, value: isExpanded)
                        .frame(width: 24)
                }
            }

            // Expanded description (viewers only).
            if isExpanded, let description = activity.description, !description.isEmpty {
                Text(description)
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 48)
                    .padding(.top, OuestTheme.Spacing.xxs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(OuestTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
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

    /// Tap priority:
    /// 1. Editor → open the Edit sheet (primary action).
    /// 2. Viewer with hidden content → toggle the inline description.
    /// 3. Otherwise → no-op (no actions available).
    private func handleTap() {
        if let onEdit {
            HapticFeedback.light()
            onEdit()
            return
        }
        if hasMoreToReveal {
            HapticFeedback.selection()
            withAnimation(OuestTheme.Anim.smooth) {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    VStack {
        ActivityCardView(
            activity: Activity(
                dayId: UUID(),
                title: "Sagrada Familia Tour",
                description: "Guided tour of Gaudi's masterpiece. A favourite of locals, often missed by guidebooks.",
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

        ActivityCardView(
            activity: Activity(
                dayId: UUID(),
                title: "Read-only view",
                description: "Viewer-mode sees a chevron and taps to expand the description inline.",
                category: .food,
                sortOrder: 1
            )
        )
    }
    .padding()
}
