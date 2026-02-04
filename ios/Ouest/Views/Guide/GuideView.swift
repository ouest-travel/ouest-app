import SwiftUI

struct GuideView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                            Text("Travel Guide")
                                .font(OuestTheme.Fonts.title)
                                .foregroundColor(OuestTheme.Colors.text)

                            Text("Tools to help you plan your trip")
                                .font(OuestTheme.Fonts.subheadline)
                                .foregroundColor(OuestTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, OuestTheme.Spacing.md)

                        // Guide Tools Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: OuestTheme.Spacing.md) {
                            GuideToolCard(
                                title: "Entry Requirements",
                                subtitle: "Visa & travel rules",
                                icon: "doc.text.fill",
                                gradient: LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ) {
                                // Navigate to Entry Requirements
                            }

                            GuideToolCard(
                                title: "Budget Tracker",
                                subtitle: "Track expenses",
                                icon: "creditcard.fill",
                                gradient: LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ) {
                                // Navigate to Budget
                            }

                            GuideToolCard(
                                title: "Destination Guide",
                                subtitle: "City highlights",
                                icon: "map.fill",
                                gradient: LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ) {
                                // Coming soon
                            }

                            GuideToolCard(
                                title: "Travel Checklist",
                                subtitle: "Packing list",
                                icon: "checklist",
                                gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ) {
                                // Coming soon
                            }
                        }
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

struct GuideToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(.white)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(OuestTheme.Spacing.md)
            .frame(height: 140)
            .background(gradient)
            .cornerRadius(OuestTheme.CornerRadius.large)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GuideView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
