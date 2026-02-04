import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var demoModeManager: DemoModeManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var stats = ProfileStats.empty
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Profile Header
                        profileHeaderView

                        // Stats Grid
                        statsGridView

                        // Settings
                        settingsView
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .onAppear {
                loadStats()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeaderView: some View {
        OuestCard {
            VStack(spacing: OuestTheme.Spacing.md) {
                // Avatar
                OuestAvatar(currentProfile, size: .xlarge)

                // Name & Handle
                VStack(spacing: 4) {
                    Text(currentProfile?.displayNameOrEmail ?? "User")
                        .font(OuestTheme.Fonts.title3)
                        .foregroundColor(OuestTheme.Colors.text)

                    if let handle = currentProfile?.handle {
                        Text("@\(handle)")
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                }

                // Edit Profile Button
                OuestButton("Edit Profile", style: .secondary, size: .small) {
                    showEditProfile = true
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, OuestTheme.Spacing.md)
    }

    // MARK: - Stats Grid

    private var statsGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: OuestTheme.Spacing.sm) {
            StatCard(
                title: "Countries",
                value: "\(stats.countriesVisited)",
                icon: "globe",
                color: .blue
            )

            StatCard(
                title: "Trips",
                value: "\(stats.totalTrips)",
                icon: "airplane",
                color: .green
            )

            StatCard(
                title: "Memories",
                value: "\(stats.memories)",
                icon: "heart.fill",
                color: .pink
            )

            StatCard(
                title: "Saved",
                value: "\(stats.savedItineraries)",
                icon: "bookmark.fill",
                color: .orange
            )
        }
    }

    // MARK: - Settings

    private var settingsView: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            // Theme Toggle
            SettingsRow(
                title: "Dark Mode",
                icon: "moon.fill"
            ) {
                Toggle("", isOn: Binding(
                    get: { themeManager.isDark },
                    set: { themeManager.setDarkMode($0) }
                ))
                .labelsHidden()
            }

            // Demo Mode Toggle
            SettingsRow(
                title: "Demo Mode",
                icon: "play.circle.fill"
            ) {
                Toggle("", isOn: $demoModeManager.isDemoMode)
                    .labelsHidden()
            }

            Divider()
                .padding(.vertical, OuestTheme.Spacing.xs)

            // Saved Itineraries
            SettingsRow(
                title: "Saved Itineraries",
                icon: "bookmark.fill",
                showChevron: true
            ) {}

            // Help
            SettingsRow(
                title: "Help & Support",
                icon: "questionmark.circle.fill",
                showChevron: true
            ) {}

            Divider()
                .padding(.vertical, OuestTheme.Spacing.xs)

            // Sign Out
            Button {
                Task {
                    await authManager.signOut()
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(OuestTheme.Colors.error)

                    Text("Sign Out")
                        .foregroundColor(OuestTheme.Colors.error)

                    Spacer()
                }
                .padding(OuestTheme.Spacing.md)
            }
        }
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
    }

    // MARK: - Helpers

    private var currentProfile: Profile? {
        demoModeManager.isDemoMode ? DemoModeManager.demoProfile : authManager.profile
    }

    private func loadStats() {
        if demoModeManager.isDemoMode {
            stats = ProfileStats.demo
        } else {
            // TODO: Load real stats
            stats = ProfileStats.empty
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(OuestTheme.Fonts.title2)
                .foregroundColor(OuestTheme.Colors.text)

            Text(title)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Settings Row

struct SettingsRow<Trailing: View>: View {
    let title: String
    let icon: String
    var showChevron: Bool = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(OuestTheme.Colors.primary)
                .frame(width: 24)

            Text(title)
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.text)

            Spacer()

            trailing()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(OuestTheme.Colors.textTertiary)
            }
        }
        .padding(OuestTheme.Spacing.md)
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Text("Edit Profile - Coming Soon")
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}
