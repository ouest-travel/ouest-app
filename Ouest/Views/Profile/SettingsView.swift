import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

    // Notification preferences
    @State private var preferences: NotificationPreference?
    @State private var preferencesLoaded = false

    var body: some View {
        List {
            // MARK: - Account Section

            Section {
                if let email = authViewModel.currentUser?.email {
                    HStack {
                        Label("Email", systemImage: "envelope.fill")
                        Spacer()
                        Text(email)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .font(OuestTheme.Typography.caption)
                    }
                }

                if let handle = authViewModel.currentUser?.handle {
                    HStack {
                        Label("Handle", systemImage: "at")
                        Spacer()
                        Text("@\(handle)")
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .font(OuestTheme.Typography.caption)
                    }
                }
            } header: {
                Text("Account")
            }

            // MARK: - Notifications Section

            if preferencesLoaded, let prefs = Binding($preferences) {
                Section {
                    notificationToggle("Trip Invites", icon: "person.badge.plus", isOn: prefs.tripInvites)
                    notificationToggle("Expenses", icon: "dollarsign.circle", isOn: prefs.newExpenses)
                    notificationToggle("Comments", icon: "bubble.left", isOn: prefs.newComments)
                    notificationToggle("Likes", icon: "heart", isOn: prefs.tripLikes)
                    notificationToggle("Followers", icon: "person.fill.checkmark", isOn: prefs.newFollowers)
                    notificationToggle("Polls", icon: "chart.bar", isOn: prefs.newPolls)
                    notificationToggle("Journal Entries", icon: "book", isOn: prefs.journalEntries)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Choose which notifications you'd like to receive.")
                }
            }

            // MARK: - Actions Section

            Section {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            } header: {
                Text("Actions")
            }

            // MARK: - About Section

            Section {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .font(OuestTheme.Typography.caption)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Made with ♥ by Ouest")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, OuestTheme.Spacing.lg)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPreferences()
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task { await authViewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Placeholder — account deletion requires server-side implementation
            }
        } message: {
            Text("This action is permanent and cannot be undone. All your trips, itineraries, and data will be deleted.")
        }
    }

    // MARK: - Notification Toggle

    private func notificationToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                Task { await savePreferences() }
            }
        )) {
            Label(label, systemImage: icon)
        }
        .tint(OuestTheme.Colors.brand)
    }

    // MARK: - Preferences Helpers

    private func loadPreferences() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            if let existing = try await NotificationService.fetchPreferences(userId: userId) {
                preferences = existing
            } else {
                preferences = .defaults(userId: userId)
            }
            preferencesLoaded = true
        } catch {
            // Default to all enabled if fetch fails
            preferences = .defaults(userId: userId)
            preferencesLoaded = true
        }
    }

    private func savePreferences() async {
        guard let prefs = preferences else { return }
        do {
            try await NotificationService.updatePreferences(prefs)
        } catch {
            print("[Settings] Failed to save notification preferences: \(error.localizedDescription)")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthViewModel())
    }
}
