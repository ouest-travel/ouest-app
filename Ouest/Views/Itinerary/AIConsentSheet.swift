import SwiftUI

// MARK: - AI Consent

/// Records whether a user has agreed to send trip details to Anthropic
/// before the first AI generate or import. App Store Guideline 5.1.2(i)
/// requires disclosing third-party AI sharing and getting explicit
/// permission first — a fineprint line alone doesn't count.
///
/// Stored per user per device in UserDefaults, so a second account on the
/// same phone is asked again.
enum AIConsent {
    private static func key(for userId: UUID) -> String {
        "aiConsentGranted.\(userId.uuidString.lowercased())"
    }

    static func hasConsented(_ userId: UUID?) -> Bool {
        guard let userId else { return false }
        return UserDefaults.standard.bool(forKey: key(for: userId))
    }

    static func grant(_ userId: UUID?) {
        guard let userId else { return }
        UserDefaults.standard.set(true, forKey: key(for: userId))
    }
}

extension View {
    /// Present the one-time AI consent sheet. `onAllow` runs after the user
    /// agrees, so the caller can continue the action they started.
    func aiConsentSheet(
        isPresented: Binding<Bool>,
        includesPastedText: Bool = false,
        onAllow: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            AIConsentSheet(includesPastedText: includesPastedText, onAllow: onAllow)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sheet

private struct AIConsentSheet: View {
    let includesPastedText: Bool
    let onAllow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    private static let privacyURL = URL(string: "https://links.ouest.travel/privacy")!

    private var sharedItems: [(symbol: String, text: String)] {
        var items: [(String, String)] = [
            ("mappin.and.ellipse", "Destination, dates, title and description of this trip"),
            ("person.2", "Group size, budget and currency"),
            ("sparkles", "The vibes you pick, your travel interests and nationality"),
            ("clock.arrow.circlepath", "Destinations and activities from your recent trips"),
        ]
        if includesPastedText {
            items.append(("doc.on.clipboard", "The text or link you paste to import"))
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OuestTheme.Layout.sectionGap) {
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(OuestTheme.Icon.feature)
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                            .accessibilityHidden(true)
                        Text("Plan with AI")
                            .font(OuestTheme.Typography.screenTitle)
                            .foregroundStyle(OuestTheme.Colors.textPrimary)
                        Text("Ouest uses Claude, an AI model made by Anthropic, to draft itineraries. To do that, we send Anthropic some details about you and this trip.")
                            .font(OuestTheme.Typography.body)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
                        Text("What we send")
                            .font(OuestTheme.Typography.sectionTitle)
                            .foregroundStyle(OuestTheme.Colors.textPrimary)
                        ForEach(sharedItems, id: \.text) { item in
                            Label {
                                Text(item.text)
                                    .font(OuestTheme.Typography.body)
                                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                            } icon: {
                                Image(systemName: item.symbol)
                                    .font(OuestTheme.Icon.inline)
                                    .foregroundStyle(OuestTheme.Colors.brandInk)
                            }
                        }
                    }
                    .padding(OuestTheme.Layout.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OuestTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg, style: .continuous))
                    .ouestElevation(.sm)

                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                        Text("We never send your email, photos, expenses or journal. Anthropic processes these details only to generate your itinerary.")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                        Link("Read our privacy policy", destination: Self.privacyURL)
                            .font(OuestTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(OuestTheme.Colors.brandInk)
                    }

                    VStack(spacing: OuestTheme.Spacing.md) {
                        OuestButton(title: "Allow and continue") {
                            AIConsent.grant(authViewModel.currentUser?.id)
                            dismiss()
                            onAllow()
                        }
                        Button("Not now") { dismiss() }
                            .font(OuestTheme.Typography.body.weight(.semibold))
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, OuestTheme.Layout.pageGutter)
                .padding(.vertical, OuestTheme.Spacing.xxl)
            }
            .background(OuestTheme.Colors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    Color.clear
        .aiConsentSheet(isPresented: .constant(true), includesPastedText: true) { }
        .environment(AuthViewModel())
}
