import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar and name
                VStack(spacing: 12) {
                    AvatarView(url: authViewModel.currentUser?.avatarUrl, size: 80)

                    VStack(spacing: 4) {
                        Text(authViewModel.currentUser?.fullName ?? "Traveler")
                            .font(.title2)
                            .fontWeight(.bold)

                        if let handle = authViewModel.currentUser?.handle {
                            Text("@\(handle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 24)

                // Stats placeholder
                HStack(spacing: 32) {
                    statItem(value: "0", label: "Trips")
                    statItem(value: "0", label: "Posts")
                    statItem(value: "0", label: "Followers")
                }

                Spacer()

                // Sign out
                OuestButton(title: "Sign Out", style: .secondary) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Profile")
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
}
