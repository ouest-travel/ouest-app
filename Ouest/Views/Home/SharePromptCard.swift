import SwiftUI

/// Home's offer to put a finished trip on Explore. `SharePrompt` decides
/// when it shows and for which trip.
///
/// Sharing opens the trip's itinerary, journal, photos and polls to every
/// signed-in user. Expenses are the group's money, so they are a separate
/// switch that starts off, and the person sharing decides.
struct SharePromptCard: View {
    let trip: Trip
    var isSharing = false
    /// Called with whether expenses should be visible to everyone too.
    let onShare: (_ includeExpenses: Bool) -> Void
    let onDismiss: () -> Void

    @State private var includeExpenses = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        OuestCard {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                HStack(alignment: .top, spacing: OuestTheme.Spacing.md) {
                    // Decorative, so at accessibility sizes the words get its room.
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "safari.fill")
                            .font(OuestTheme.Icon.control)
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                            .padding(OuestTheme.Spacing.md)
                            .background(OuestTheme.Colors.fill)
                            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md, style: .continuous))
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                        Text("Back from \(trip.destination)?")
                            .font(OuestTheme.Typography.sectionTitle)
                            .foregroundStyle(OuestTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Share it on Explore for anyone on Ouest to see.")
                            .font(OuestTheme.Typography.body)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Toggle(isOn: $includeExpenses) {
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxs) {
                        Text("Include expenses")
                            .font(OuestTheme.Typography.body.weight(.medium))
                            .foregroundStyle(OuestTheme.Colors.textPrimary)
                        Text(includeExpenses ? "Anyone viewing can see them" : "Only trip members can see them")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
                .tint(OuestTheme.Colors.brandFill)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.fill)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md, style: .continuous))
                .disabled(isSharing)
                .onChange(of: includeExpenses) { HapticFeedback.selection() }

                OuestButton(title: "Share trip", isLoading: isSharing) { onShare(includeExpenses) }

                Button {
                    HapticFeedback.light()
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(OuestTheme.Typography.body.weight(.medium))
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSharing)
            }
        }
    }
}

// MARK: - Previews

private let previewTrip = Trip(
    id: UUID(), createdBy: UUID(), title: "Lisbon with friends", destination: "Lisbon, Portugal",
    description: nil, coverImageUrl: nil, startDate: nil, endDate: nil,
    status: .completed, isPublic: false, budget: nil, currency: nil, votingEnabled: nil,
    tags: nil, countryCodes: ["PRT"], coverAttribution: nil, coverAttributionUrl: nil,
    createdAt: nil, updatedAt: nil
)

#Preview("Light") {
    SharePromptCard(trip: previewTrip, onShare: { _ in }, onDismiss: {})
        .padding()
        .background(OuestTheme.Colors.background)
}

#Preview("Dark, sharing") {
    SharePromptCard(trip: previewTrip, isSharing: true, onShare: { _ in }, onDismiss: {})
        .padding()
        .background(OuestTheme.Colors.background)
        .preferredColorScheme(.dark)
}

#Preview("Largest type") {
    ScrollView {
        SharePromptCard(trip: previewTrip, onShare: { _ in }, onDismiss: {})
            .padding()
    }
    .background(OuestTheme.Colors.background)
    .dynamicTypeSize(.accessibility5)
}
