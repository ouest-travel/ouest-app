import SwiftUI

/// Navigation destination for follow lists
struct FollowListDestination: Hashable {
    let userId: UUID
    let listType: FollowListView.ListType
}

struct UserProfileView: View {
    let userId: UUID
    @State private var viewModel: UserProfileViewModel
    @State private var contentAppeared = false
    @State private var equippedStickers: [UserSticker] = []
    @State private var showAvatarViewer = false

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
        .navigationDestination(for: FollowListDestination.self) { dest in
            FollowListView(userId: dest.userId, listType: dest.listType)
        }
        .fullScreenCover(isPresented: $showAvatarViewer) {
            FullScreenAvatarView(
                url: viewModel.profile?.avatarUrl,
                name: viewModel.profile?.fullName
            )
        }
        .task {
            await viewModel.loadProfile()
            equippedStickers = (try? await StickerService.fetchEquippedStickers(userId: userId)) ?? []
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
    }

    // MARK: - Profile Content

    /// Whether this profile's details are hidden (private + not following + not own profile)
    private var isProfileLocked: Bool {
        guard let profile = viewModel.profile else { return false }
        return profile.isPrivate && !viewModel.isFollowing && !viewModel.isOwnProfile
    }

    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xl) {
                // Profile card (gradient + avatar + name + stats + interests)
                profileCard(profile)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                // Follow button (outside card for prominence)
                if !viewModel.isOwnProfile {
                    OuestButton(
                        title: viewModel.isFollowing ? "Following" : "Follow",
                        style: viewModel.isFollowing ? .secondary : .primary
                    ) {
                        viewModel.toggleFollow()
                    }
                    .frame(width: 200)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)
                }

                if isProfileLocked {
                    // Private profile — show lock message
                    privateProfileNotice
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)
                } else {
                    // Bio (outside card)
                    if let bio = profile.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.12)
                    }

                    // Public trips
                    if !viewModel.publicTrips.isEmpty {
                        tripsSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                    } else {
                        noTripsSection
                            .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
                    }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.lg)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    // MARK: - Private Profile Notice

    private var privateProfileNotice: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("This profile is private")
                .font(OuestTheme.Typography.cardTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
            Text("Follow this traveler to see their trips and interests.")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(OuestTheme.Spacing.xxxl)
    }

    // MARK: - Profile Card

    private func profileCard(_ profile: Profile) -> some View {
        VStack(spacing: 0) {
            // Empty space sitting over the gradient area — with sticker overlay
            ZStack(alignment: .topTrailing) {
                Spacer()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)

                // Equipped stickers (read-only display)
                if !equippedStickers.isEmpty {
                    stickerCluster
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
            }

            // Avatar straddling the gradient / surface boundary — tappable
            Button {
                if profile.avatarUrl != nil {
                    showAvatarViewer = true
                }
            } label: {
                AvatarView(url: profile.avatarUrl, size: 80)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .ouestElevation(.lg)
            }
            .buttonStyle(.plain)

            // Profile info on surface
            VStack(spacing: OuestTheme.Spacing.md) {
                VStack(spacing: OuestTheme.Spacing.xs) {
                    Text(profile.fullName ?? "Traveler")
                        .font(OuestTheme.Typography.screenTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    if let handle = profile.handle {
                        Text("@\(handle)")
                            .font(.subheadline)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                // Stats row
                HStack(spacing: OuestTheme.Spacing.xxl) {
                    cardStatItem(value: viewModel.publicTrips.count, label: "Trips")

                    NavigationLink(value: FollowListDestination(userId: userId, listType: .followers)) {
                        cardStatItem(value: viewModel.followerCount, label: "Followers")
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: FollowListDestination(userId: userId, listType: .following)) {
                        cardStatItem(value: viewModel.followingCount, label: "Following")
                    }
                    .buttonStyle(.plain)
                }

                // Interest tags inside card (only for non-locked profiles)
                if !isProfileLocked, let interests = profile.travelInterests, !interests.isEmpty {
                    interestTags(interests)
                }
            }
            .padding(.top, OuestTheme.Spacing.md)
            .padding(.bottom, OuestTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(
            VStack(spacing: 0) {
                OuestTheme.Colors.decorGradient
                    .frame(height: 140)
                Color("Surface")
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
        .ouestElevation(.sm)
    }

    // MARK: - Sticker Cluster

    private var stickerCluster: some View {
        let rotations: [Double] = [-6, 4, -3, 7]
        return HStack(spacing: -8) {
            ForEach(Array(equippedStickers.prefix(4).enumerated()), id: \.element.id) { index, sticker in
                if let type = sticker.type {
                    StickerBadgeView(stickerType: type, isUnlocked: true, size: .small)
                        .rotationEffect(.degrees(rotations[index % rotations.count]))
                }
            }
        }
    }

    // MARK: - Interest Tags (Filled)

    private func interestTags(_ interests: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(interests, id: \.self) { interest in
                    if let ti = TravelInterest(rawValue: interest) {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: ti.icon)
                                .font(.caption)
                            Text(ti.label)
                                .font(OuestTheme.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, OuestTheme.Spacing.md)
                        .padding(.vertical, OuestTheme.Spacing.xs)
                        .background(ti.color)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
        }
    }

    private func cardStatItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(OuestTheme.Typography.cardTitle)
                .fontWeight(.bold)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
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

}

#Preview {
    NavigationStack {
        UserProfileView(userId: UUID())
    }
}
