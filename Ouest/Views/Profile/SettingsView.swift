import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false

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
