import SwiftUI

/// Navigation destination for saved trips full list
private struct SavedTripsDestination: Hashable {}

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showEditProfile = false
    @State private var showStickers = false
    @State private var showAvatarViewer = false
    @State private var contentAppeared = false
    @State private var equippedStickers: [UserSticker] = []

    // MARK: - Stats (loaded async)

    @State private var tripCount = 0
    @State private var followerCount = 0
    @State private var followingCount = 0

    // MARK: - Saved Trips

    @State private var savedTrips: [Trip] = []
    @State private var savedTripMembers: [UUID: [TripMemberPreview]] = [:]
    @State private var isSavedTripsLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let profile = authViewModel.currentUser {
                    profileContent(profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environment(authViewModel)
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { tripId in
                TripDetailView(tripId: tripId)
                    .environment(authViewModel)
            }
            .navigationDestination(for: SavedTripsDestination.self) { _ in
                SavedTripsView()
                    .environment(authViewModel)
            }
            .navigationDestination(for: FollowListDestination.self) { dest in
                FollowListView(userId: dest.userId, listType: dest.listType)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(authViewModel)
            }
            .sheet(isPresented: $showStickers) {
                if let userId = authViewModel.currentUser?.id {
                    StickersCollectionView(
                        viewModel: StickersViewModel(userId: userId),
                        userName: authViewModel.currentUser?.fullName ?? "Traveler"
                    )
                }
            }
            .fullScreenCover(isPresented: $showAvatarViewer) {
                FullScreenAvatarView(
                    url: authViewModel.currentUser?.avatarUrl,
                    name: authViewModel.currentUser?.fullName
                )
            }
            .task {
                await loadStats()
                await loadEquippedStickers()
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
            .onChange(of: showEditProfile) { _, isPresented in
                if !isPresented {
                    // Refresh profile + stats after edit dismissal
                    Task {
                        await authViewModel.refreshProfile()
                        await loadStats()
                    }
                }
            }
            .onChange(of: showStickers) { _, isPresented in
                if !isPresented {
                    // Refresh equipped stickers after collection view dismissal
                    Task { await loadEquippedStickers() }
                }
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xl) {
                // Profile card (gradient banner + avatar + info + stats + interests)
                profileCard(profile)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                // Bio (outside card)
                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, OuestTheme.Spacing.lg)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)
                }

                // Edit button
                OuestButton(title: "Edit Profile") {
                    showEditProfile = true
                }
                .frame(width: 200)
                .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)

                // Saved trips
                savedTripsSection
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.25)
            }
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
        .refreshable {
            await authViewModel.refreshProfile()
            await loadStats()
        }
    }

    // MARK: - Profile Card

    private func profileCard(_ profile: Profile) -> some View {
        VStack(spacing: 0) {
            // Empty space sitting over the gradient area — with sticker overlay
            ZStack(alignment: .topTrailing) {
                Spacer()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)

                // Stickers in top-right of gradient — cluster if equipped, button if not
                Button {
                    showStickers = true
                } label: {
                    if equippedStickers.isEmpty {
                        // Empty state — subtle "view stickers" badge
                        Image(systemName: "star.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        stickerCluster
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, 12)
            }

            // Avatar straddling the gradient / surface boundary — tappable
            Button {
                if profile.avatarUrl != nil {
                    showAvatarViewer = true
                }
            } label: {
                AvatarView(url: profile.avatarUrl, size: 80)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(OuestTheme.Shadow.lg)
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
                    cardStatItem(value: tripCount, label: "Trips")

                    NavigationLink(value: FollowListDestination(userId: profile.id, listType: .followers)) {
                        cardStatItem(value: followerCount, label: "Followers")
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: FollowListDestination(userId: profile.id, listType: .following)) {
                        cardStatItem(value: followingCount, label: "Following")
                    }
                    .buttonStyle(.plain)
                }

                // Interest tags inside card
                if let interests = profile.travelInterests, !interests.isEmpty {
                    interestTags(interests)
                }
            }
            .padding(.top, OuestTheme.Spacing.md)
            .padding(.bottom, OuestTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [OuestTheme.Colors.brand, OuestTheme.Colors.brandCyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                Color("Surface")
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
        .shadow(OuestTheme.Shadow.sm)
        .padding(.horizontal, OuestTheme.Spacing.lg)
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
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
    }

    // MARK: - Load Stats + Saved Trips

    private func loadStats() async {
        guard let userId = authViewModel.currentUser?.id else { return }

        isSavedTripsLoading = true

        // Fetch counts + saved trips in parallel
        async let trips = TripService.fetchMyTrips()
        async let followers = CommunityService.fetchFollowerCount(userId: userId)
        async let following = CommunityService.fetchFollowingCount(userId: userId)
        async let saved = CommunityService.fetchSavedTrips(userId: userId)

        tripCount = (try? await trips.count) ?? 0
        followerCount = (try? await followers) ?? 0
        followingCount = (try? await following) ?? 0
        savedTrips = (try? await saved) ?? []

        // Fetch member previews for saved trips (non-critical)
        if !savedTrips.isEmpty {
            let tripIds = savedTrips.map(\.id)
            let members = (try? await TripService.fetchMemberPreviews(tripIds: tripIds)) ?? []
            savedTripMembers = Dictionary(grouping: members, by: \.tripId)
        } else {
            savedTripMembers = [:]
        }

        isSavedTripsLoading = false
    }

    // MARK: - Load Equipped Stickers

    private func loadEquippedStickers() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        // Check for newly earned stickers, then load equipped
        _ = try? await StickerService.checkAndGrant(userId: userId)
        equippedStickers = (try? await StickerService.fetchEquippedStickers(userId: userId)) ?? []
    }

    // MARK: - Saved Trips Section

    private var savedTripsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            // Section header → taps to full list
            NavigationLink(value: SavedTripsDestination()) {
                HStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(OuestTheme.Colors.brand)
                    Text("Saved Trips")
                        .font(OuestTheme.Typography.sectionTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    if !savedTrips.isEmpty {
                        Text("\(savedTrips.count)")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.brand)
                            .padding(.horizontal, OuestTheme.Spacing.sm)
                            .padding(.vertical, OuestTheme.Spacing.xxs)
                            .background(OuestTheme.Colors.brandLight)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Content: loading / empty / cards
            if isSavedTripsLoading {
                savedTripsSkeletonRow
            } else if savedTrips.isEmpty {
                savedTripsEmptyState
            } else {
                savedTripsHorizontalScroll
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
    }

    private var savedTripsHorizontalScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.md) {
                ForEach(Array(savedTrips.prefix(5).enumerated()), id: \.element.id) { index, trip in
                    NavigationLink(value: trip.id) {
                        TripCardView(
                            trip: trip,
                            style: .standard,
                            members: savedTripMembers[trip.id] ?? []
                        )
                        .frame(width: 280)
                    }
                    .buttonStyle(ScaledButtonStyle(scale: 0.98))
                    .cardEntrance(isVisible: contentAppeared, delay: 0.3 + Double(index) * 0.06)
                }
            }
        }
    }

    private var savedTripsEmptyState: some View {
        VStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("No saved trips yet")
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
            Text("Bookmark trips from Explore to see them here")
                .font(OuestTheme.Typography.micro)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(OuestTheme.Spacing.xxl)
    }

    private var savedTripsSkeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OuestTheme.Spacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonTripCard()
                        .frame(width: 280)
                }
            }
        }
    }

    // MARK: - Helpers

    private func flag(for countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2 else { return "" }
        return code.unicodeScalars.reduce("") { result, scalar in
            result + String(UnicodeScalar(scalar.value + 0x1F1A5)!)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
}
