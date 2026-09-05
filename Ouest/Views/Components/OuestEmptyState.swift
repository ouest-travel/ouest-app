import SwiftUI

/// Empty-state screen built on iOS 17's `ContentUnavailableView`, which
/// hands us correct symbol scaling, dynamic-type layout, and VoiceOver
/// order for free.
///
/// The old `EmptyStateView` reimplemented all of that by hand and got the
/// symbol wrong (`.font(.system(size: 48))`, no Dynamic Type). It stays
/// briefly for the two screens still using it while adoption completes;
/// prefer this one everywhere else.
///
/// ## Copy rules (design brief §OuestEmptyState)
///
/// - The **title** says what the screen is *for*, not what is missing:
///   "Plan your days", not "No itinerary yet". Reserve "No X yet" for
///   states the user genuinely can't act on.
/// - The **message** explains what will fill the space if the user acts.
/// - At most one **primary** action and one **secondary** text action.
///   Never a primary a view-only member cannot use.
/// - No exclamation marks.
struct OuestEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    /// Extra line under the message. Use for context that isn't the
    /// message itself — e.g. "You have view-only access."
    var footnote: String? = nil

    /// The recommended next step. Rendered as an OuestButton .primary.
    var primary: Action? = nil

    /// Optional secondary action rendered as brand-coloured text — never
    /// a second button. Use it for the alternative path (e.g. "Enter a
    /// code" beside "Create Trip").
    var secondary: Action? = nil

    struct Action {
        let title: String
        let perform: () -> Void

        init(_ title: String, perform: @escaping () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            VStack(spacing: OuestTheme.Spacing.xs) {
                Text(message)
                if let footnote {
                    Text(footnote)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textTertiary)
                }
            }
        } actions: {
            if primary != nil || secondary != nil {
                VStack(spacing: OuestTheme.Spacing.md) {
                    if let primary {
                        OuestButton(title: primary.title, action: primary.perform)
                            .frame(maxWidth: 280)
                    }
                    if let secondary {
                        Button(secondary.title, action: secondary.perform)
                            .font(OuestTheme.Typography.body)
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                    }
                }
                .padding(.top, OuestTheme.Spacing.md)
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty — Plan your days") {
    OuestEmptyState(
        symbol: "sparkles",
        title: "Plan your days",
        message: "Add activities to see them here, or let AI draft a first pass.",
        primary: .init("Generate with AI") {},
        secondary: .init("Add manually") {}
    )
}

#Preview("Empty — view-only") {
    OuestEmptyState(
        symbol: "creditcard",
        title: "Track shared spending",
        message: "Expenses added here will show up for everyone on the trip.",
        footnote: "You have view-only access."
    )
}

#Preview("Empty — Dark") {
    OuestEmptyState(
        symbol: "sparkles",
        title: "Plan your days",
        message: "Add activities to see them here, or let AI draft a first pass.",
        primary: .init("Generate with AI") {},
        secondary: .init("Add manually") {}
    )
    .preferredColorScheme(.dark)
}
