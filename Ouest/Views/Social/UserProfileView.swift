import SwiftUI

struct UserProfileView: View {
    let userId: UUID
    @State private var viewModel: UserProfileViewModel
    @State private var contentAppeared = false

    init(userId: UUID) {
        self.userId = userId
        self._viewModel = State(initialValue: UserProfileViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.profile == nil {
                ErrorView(message: error) {
                    Task { await viewModel.loadProfile() }
                }
            } else if let profile = viewModel.profile {
                profileContent(profile)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xl) {
                // Profile header
                profileHeader(profile)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                // Travel interests
                if let interests = profile.travelInterests, !interests.isEmpty {
                    interestTags(interests)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)
                }

                // Stats + Follow button
                statsSection
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                // Public trips
                if !viewModel.publicTrips.isEmpty {
                    tripsSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                } else {
                    noTripsSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.lg)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Profile Header

    private func profileHeader(_ profile: Profile) -> some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            AvatarView(url: profile.avatarUrl, size: 80)
                .shadow(OuestTheme.Shadow.md)

            VStack(spacing: OuestTheme.Spacing.xs) {
                Text(profile.fullName ?? "Traveler")
                    .font(OuestTheme.Typography.screenTitle)

                if let handle = profile.handle {
                    Text("@\(handle)")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let nationality = profile.nationality, !nationality.isEmpty {
                HStack(spacing: OuestTheme.Spacing.xs) {
                    Text(flag(for: nationality))
                    Text(nationality)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Interest Tags

    private func interestTags(_ interests: [String]) -> some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    ForEach(interests, id: \.self) { interest in
                        if let ti = TravelInterest(rawValue: interest) {
                            HStack(spacing: OuestTheme.Spacing.xs) {
                                Image(systemName: ti.icon)
                                    .font(.caption)
                                Text(ti.label)
                                    .font(OuestTheme.Typography.caption)
                            }
                            .foregroundStyle(ti.color)
                            .padding(.horizontal, OuestTheme.Spacing.md)
                            .padding(.vertical, OuestTheme.Spacing.xs)
                            .background(ti.color.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.xxl) {
                statItem(value: viewModel.publicTrips.count, label: "Trips")
                statItem(value: viewModel.followerCount, label: "Followers")
                statItem(value: viewModel.followingCount, label: "Following")
            }

            if !viewModel.isOwnProfile {
                OuestButton(
                    title: viewModel.isFollowing ? "Following" : "Follow",
                    style: viewModel.isFollowing ? .secondary : .primary
                ) {
                    viewModel.toggleFollow()
                }
                .frame(width: 200)
            }
        }
        .padding(OuestTheme.Spacing.lg)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(OuestTheme.Typography.cardTitle)
                .fontWeight(.bold)
            Text(label)
                .font(OuestTheme.Typography.micro)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
    }

    // MARK: - Trips Section

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "airplane")
                    .foregroundStyle(OuestTheme.Colors.brand)
                Text("Public Trips")
                    .font(OuestTheme.Typography.sectionTitle)
            }

            LazyVStack(spacing: OuestTheme.Spacing.md) {
                ForEach(Array(viewModel.publicTrips.enumerated()), id: \.element.id) { index, trip in
                    NavigationLink(value: trip.id) {
                        TripCardView(
                            trip: trip,
                            style: .standard,
                            members: viewModel.tripMembers[trip.id] ?? []
                        )
                    }
                    .buttonStyle(ScaledButtonStyle(scale: 0.98))
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25 + Double(index) * 0.06)
                }
            }
        }
    }

    private var noTripsSection: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "suitcase")
                .font(.title2)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("No public trips yet")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(OuestTheme.Spacing.xxxl)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Helpers

    /// Convert a country code to flag emoji
    private func flag(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "" }
        return code.unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(scalar.value + 0x1F1A5)!)
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(userId: UUID())
    }
}
