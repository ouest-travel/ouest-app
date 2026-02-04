import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ProfileViewModel

    @State private var showEditProfile = false
    @State private var showSettings = false

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

                        // Quick Actions
                        quickActionsView

                        // Menu Items
                        menuItemsView
                    }
                    .padding(.horizontal, OuestTheme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(OuestTheme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
        OuestGradientCard(gradient: LinearGradient(colors: [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)) {
            VStack(spacing: OuestTheme.Spacing.md) {
                // Avatar with edit button
                ZStack(alignment: .bottomTrailing) {
                    OuestAvatar(currentProfile, size: .xlarge)

                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .background(Circle().fill(OuestTheme.Colors.Brand.blue))
                    }
                    .offset(x: 4, y: 4)
                }

                // Name & Handle
                VStack(spacing: 4) {
                    Text(currentProfile?.displayNameOrEmail ?? "User")
                        .font(OuestTheme.Fonts.title2)
                        .foregroundColor(.white)

                    if let handle = currentProfile?.handle {
                        Text("@\(handle)")
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if let email = currentProfile?.email {
                        Text(email)
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
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
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: OuestTheme.Spacing.sm) {
            ProfileStatItem(value: "\(viewModel.stats.totalTrips)", label: "Trips", icon: "airplane")
            ProfileStatItem(value: "\(viewModel.stats.countriesVisited)", label: "Countries", icon: "globe")
            ProfileStatItem(value: "\(viewModel.stats.memories)", label: "Memories", icon: "heart.fill")
            ProfileStatItem(value: "\(viewModel.stats.savedItineraries)", label: "Saved", icon: "bookmark.fill")
        }
    }

    // MARK: - Quick Actions

    private var quickActionsView: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            QuickActionButton(
                icon: "bookmark.fill",
                label: "Saved",
                color: OuestTheme.Colors.Brand.coral
            ) {
                // Navigate to saved
            }

            QuickActionButton(
                icon: "photo.stack",
                label: "Memories",
                color: OuestTheme.Colors.Brand.pink
            ) {
                // Navigate to memories
            }

            QuickActionButton(
                icon: "person.2.fill",
                label: "Friends",
                color: OuestTheme.Colors.Brand.blue
            ) {
                // Navigate to friends
            }

            QuickActionButton(
                icon: "chart.bar.fill",
                label: "Stats",
                color: OuestTheme.Colors.Brand.indigo
            ) {
                // Navigate to stats
            }
        }
    }

    // MARK: - Menu Items

    private var menuItemsView: some View {
        VStack(spacing: 0) {
            // My Trips
            NavigationLink(destination: MyTripsView()) {
                MenuRow(icon: "airplane.departure", title: "My Trips", subtitle: "\(viewModel.stats.totalTrips) trips")
            }

            Divider().padding(.leading, 56)

            // Saved Itineraries
            NavigationLink(destination: SavedItinerariesView(viewModel: viewModel)) {
                MenuRow(icon: "bookmark.fill", title: "Saved Itineraries", subtitle: "\(viewModel.stats.savedItineraries) saved")
            }

            Divider().padding(.leading, 56)

            // Notifications
            NavigationLink(destination: NotificationsSettingsView()) {
                MenuRow(icon: "bell.fill", title: "Notifications", subtitle: "Manage alerts")
            }

            Divider().padding(.leading, 56)

            // Privacy
            NavigationLink(destination: PrivacySettingsView()) {
                MenuRow(icon: "lock.fill", title: "Privacy", subtitle: "Control your data")
            }

            Divider().padding(.leading, 56)

            // Help
            NavigationLink(destination: HelpView()) {
                MenuRow(icon: "questionmark.circle.fill", title: "Help & Support", subtitle: "Get assistance")
            }

            Divider().padding(.leading, 56)

            // Sign Out
            Button {
                Task {
                    await appState.authViewModel.signOut()
                }
            } label: {
                HStack(spacing: OuestTheme.Spacing.md) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(OuestTheme.Colors.error)
                        .frame(width: 28)

                    Text("Sign Out")
                        .font(OuestTheme.Fonts.body)
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

// MARK: - Profile Stat Item

struct ProfileStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(OuestTheme.Fonts.title2)
                .foregroundColor(OuestTheme.Colors.text)

            Text(label)
                .font(OuestTheme.Fonts.caption2)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: OuestTheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(OuestTheme.Colors.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OuestTheme.Fonts.body)
                    .foregroundColor(OuestTheme.Colors.text)

                Text(subtitle)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .padding(OuestTheme.Spacing.md)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var handle = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                OuestTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OuestTheme.Spacing.lg) {
                        // Avatar Section
                        avatarSection

                        // Form
                        formSection
                    }
                    .padding(OuestTheme.Spacing.md)
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
                        Task { await saveProfile() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .onAppear {
                displayName = viewModel.profile?.displayName ?? ""
                handle = viewModel.profile?.handle ?? ""
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                OuestAvatar(viewModel.profile, size: .xlarge)

                Button {
                    // Photo picker
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(OuestTheme.Spacing.sm)
                        .background(OuestTheme.Gradients.primary)
                        .clipShape(Circle())
                }
            }

            Text("Tap to change photo")
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)
        }
        .padding(.vertical, OuestTheme.Spacing.md)
    }

    private var formSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            OuestTextField(
                label: "Display Name",
                placeholder: "Your name",
                text: $displayName,
                icon: "person"
            )

            OuestTextField(
                label: "Handle",
                placeholder: "username",
                text: $handle,
                autocapitalization: .never,
                icon: "at"
            )
        }
    }

    private func saveProfile() async {
        isSaving = true
        await viewModel.updateProfile(
            displayName: displayName.isEmpty ? nil : displayName,
            handle: handle.isEmpty ? nil : handle,
            avatarUrl: nil
        )
        dismiss()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Appearance
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: Binding(
                        get: { appState.themeManager.isDark },
                        set: { appState.themeManager.setDarkMode($0) }
                    ))
                }

                // App
                Section("App") {
                    Toggle("Demo Mode", isOn: $appState.isDemoMode)

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                }

                // Links
                Section("Links") {
                    Link(destination: URL(string: "https://ouest.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(OuestTheme.Colors.textTertiary)
                        }
                    }

                    Link(destination: URL(string: "https://ouest.app/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(OuestTheme.Colors.textTertiary)
                        }
                    }
                }

                // About
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: OuestTheme.Spacing.xs) {
                            Text("Ouest")
                                .font(OuestTheme.Fonts.headline)
                                .foregroundColor(OuestTheme.Colors.text)
                            Text("Made with love for travelers")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Saved Itineraries View

struct SavedItinerariesView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            if viewModel.savedItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: OuestTheme.Spacing.md) {
                        ForEach(viewModel.savedItems) { item in
                            SavedItineraryCard(item: item)
                        }
                    }
                    .padding(OuestTheme.Spacing.md)
                }
            }
        }
        .navigationTitle("Saved Itineraries")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyStateView: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 64))
                .foregroundColor(OuestTheme.Colors.textTertiary)

            Text("No saved itineraries")
                .font(OuestTheme.Fonts.title3)
                .foregroundColor(OuestTheme.Colors.text)

            Text("Save trips from the community to view them here")
                .font(OuestTheme.Fonts.body)
                .foregroundColor(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(OuestTheme.Spacing.xl)
    }
}

// MARK: - Saved Itinerary Card

struct SavedItineraryCard: View {
    let item: SavedItineraryItem

    var body: some View {
        OuestCard {
            HStack(spacing: OuestTheme.Spacing.md) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(item.activityCategory.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Text(item.activityCategory.emoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.activityName)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(OuestTheme.Colors.text)

                    Text(item.activityLocation)
                        .font(OuestTheme.Fonts.subheadline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)

                    HStack(spacing: OuestTheme.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(item.activityTime)
                            .font(OuestTheme.Fonts.caption)

                        if let cost = item.activityCost {
                            Text("•")
                            Text(cost)
                                .font(OuestTheme.Fonts.caption)
                        }
                    }
                    .foregroundColor(OuestTheme.Colors.textTertiary)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Supporting Views

struct MyTripsView: View {
    var body: some View {
        Text("My Trips")
            .navigationTitle("My Trips")
    }
}

struct NotificationsSettingsView: View {
    @State private var pushEnabled = true
    @State private var emailEnabled = false
    @State private var tripReminders = true
    @State private var chatNotifications = true

    var body: some View {
        List {
            Section("Push Notifications") {
                Toggle("Enable Push Notifications", isOn: $pushEnabled)
            }

            Section("Notification Types") {
                Toggle("Trip Reminders", isOn: $tripReminders)
                Toggle("Chat Messages", isOn: $chatNotifications)
                Toggle("Email Updates", isOn: $emailEnabled)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct PrivacySettingsView: View {
    @State private var shareLocation = false
    @State private var publicProfile = true

    var body: some View {
        List {
            Section("Profile") {
                Toggle("Public Profile", isOn: $publicProfile)
            }

            Section("Location") {
                Toggle("Share Location", isOn: $shareLocation)
            }

            Section("Data") {
                Button("Download My Data") { }
                Button("Delete Account", role: .destructive) { }
            }
        }
        .navigationTitle("Privacy")
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Support") {
                Link(destination: URL(string: "mailto:support@ouest.app")!) {
                    Label("Contact Support", systemImage: "envelope")
                }

                Link(destination: URL(string: "https://ouest.app/faq")!) {
                    Label("FAQ", systemImage: "questionmark.circle")
                }
            }

            Section("Feedback") {
                Label("Rate the App", systemImage: "star")
                Label("Send Feedback", systemImage: "paperplane")
            }
        }
        .navigationTitle("Help & Support")
    }
}

#Preview {
    ProfileView(repositories: RepositoryProvider(isDemoMode: true))
        .environmentObject(AppState(isDemoMode: true))
}
