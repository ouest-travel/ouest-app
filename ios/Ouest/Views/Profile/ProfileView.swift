import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ProfileViewModel

    @State private var showEditProfile = false

    init(repositories: RepositoryProvider? = nil, userId: String? = nil) {
        let repos = repositories ?? RepositoryProvider()
        let id = userId ?? "demo-user"
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            profileRepository: repos.profileRepository,
            savedItineraryRepository: repos.savedItineraryRepository,
            userId: id
        ))
    }

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
                EditProfileSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refresh()
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
                value: "\(viewModel.stats.countriesVisited)",
                icon: "globe",
                color: .blue
            )

            StatCard(
                title: "Trips",
                value: "\(viewModel.stats.totalTrips)",
                icon: "airplane",
                color: .green
            )

            StatCard(
                title: "Memories",
                value: "\(viewModel.stats.memories)",
                icon: "heart.fill",
                color: .pink
            )

            StatCard(
                title: "Saved",
                value: "\(viewModel.stats.savedItineraries)",
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
                    get: { appState.themeManager.isDark },
                    set: { appState.themeManager.setDarkMode($0) }
                ))
                .labelsHidden()
            }

            // Demo Mode Toggle
            SettingsRow(
                title: "Demo Mode",
                icon: "play.circle.fill"
            ) {
                Toggle("", isOn: $appState.isDemoMode)
                    .labelsHidden()
            }

            Divider()
                .padding(.vertical, OuestTheme.Spacing.xs)

            // Saved Itineraries
            NavigationLink(destination: SavedItinerariesView()) {
                SettingsRow(
                    title: "Saved Itineraries",
                    icon: "bookmark.fill",
                    showChevron: true
                ) {}
            }
            .buttonStyle(PlainButtonStyle())

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
                    await appState.authViewModel.signOut()
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
        appState.isDemoMode ? DemoModeManager.demoProfile : viewModel.profile
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
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var handle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Display Name", text: $displayName)
                    TextField("Handle", text: $handle)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.updateProfile(
                                displayName: displayName.isEmpty ? nil : displayName,
                                handle: handle.isEmpty ? nil : handle,
                                avatarUrl: nil
                            )
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                displayName = viewModel.profile?.displayName ?? ""
                handle = viewModel.profile?.handle ?? ""
            }
        }
    }
}

// MARK: - Saved Itineraries View

struct SavedItinerariesView: View {
    var body: some View {
        Text("Saved Itineraries - Coming Soon")
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView(repositories: RepositoryProvider(isDemoMode: true))
        .environmentObject(AppState(isDemoMode: true))
}
