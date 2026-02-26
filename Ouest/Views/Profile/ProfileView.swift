import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showEditProfile = false
    @State private var contentAppeared = false

    // MARK: - Stats (loaded async)

    @State private var tripCount = 0
    @State private var followerCount = 0
    @State private var followingCount = 0

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
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environment(authViewModel)
            }
            .task {
                await loadStats()
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
            .onChange(of: showEditProfile) { _, isPresented in
                if !isPresented {
                    // Refresh stats after edit dismissal
                    Task { await loadStats() }
                }
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xl) {
                // Header
                profileHeader(profile)
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                // Travel interests
                if let interests = profile.travelInterests, !interests.isEmpty {
                    interestTags(interests)
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)
                }

                // Stats
                statsSection
                    .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                // Edit button
                OuestButton(title: "Edit Profile", style: .secondary) {
                    showEditProfile = true
                }
                .frame(width: 200)
                .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.top, OuestTheme.Spacing.lg)
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
        .refreshable {
            await authViewModel.refreshProfile()
            await loadStats()
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

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: OuestTheme.Spacing.xxl) {
            statItem(value: tripCount, label: "Trips")
            statItem(value: followerCount, label: "Followers")
            statItem(value: followingCount, label: "Following")
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

    // MARK: - Load Stats

    private func loadStats() async {
        guard let userId = authViewModel.currentUser?.id else { return }

        // Fetch counts in parallel, ignore errors individually
        async let trips = TripService.fetchMyTrips()
        async let followers = CommunityService.fetchFollowerCount(userId: userId)
        async let following = CommunityService.fetchFollowingCount(userId: userId)

        tripCount = (try? await trips.count) ?? 0
        followerCount = (try? await followers) ?? 0
        followingCount = (try? await following) ?? 0
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
