import SwiftUI

/// Displays a list of followers or following profiles
struct FollowListView: View {
    enum ListType: String, Hashable {
        case followers = "Followers"
        case following = "Following"
    }

    let userId: UUID
    let listType: ListType

    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let error = errorMessage {
                ErrorView(message: error) {
                    Task { await load() }
                }
            } else if profiles.isEmpty {
                emptyState
            } else {
                profileList
            }
        }
        .navigationTitle(listType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Profile List

    private var profileList: some View {
        ScrollView {
            LazyVStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(profiles) { profile in
                    NavigationLink {
                        UserProfileView(userId: profile.id)
                    } label: {
                        profileRow(profile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.md)
        }
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            AvatarView(url: profile.avatarUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.fullName ?? "Traveler")
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)

                if let handle = profile.handle {
                    Text("@\(handle)")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Spacer()
            Image(systemName: listType == .followers ? "person.2" : "person.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text(listType == .followers ? "No followers yet" : "Not following anyone yet")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            switch listType {
            case .followers:
                profiles = try await CommunityService.fetchFollowers(userId: userId)
            case .following:
                profiles = try await CommunityService.fetchFollowing(userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        FollowListView(userId: UUID(), listType: .followers)
    }
}
