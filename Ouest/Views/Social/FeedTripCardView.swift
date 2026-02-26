import SwiftUI

struct FeedTripCardView: View {
    let feedTrip: FeedTrip
    let onLike: () -> Void
    let onSave: () -> Void
    let onComment: () -> Void
    let onClone: () -> Void

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author Header
            authorHeader
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.sm)

            // Trip Cover
            NavigationLink(value: feedTrip.trip.id) {
                tripCover
            }
            .buttonStyle(ScaledButtonStyle(scale: 0.98))

            // Action Bar
            actionBar
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.sm)
        }
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
        .shadow(OuestTheme.Shadow.md)
    }

    // MARK: - Author Header

    private var authorHeader: some View {
        NavigationLink {
            UserProfileView(userId: feedTrip.creatorProfile.id)
        } label: {
            HStack(spacing: OuestTheme.Spacing.sm) {
                AvatarView(url: feedTrip.creatorProfile.avatarUrl, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(feedTrip.creatorProfile.fullName ?? "Traveler")
                        .font(OuestTheme.Typography.cardTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    if let handle = feedTrip.creatorProfile.handle {
                        Text("@\(handle)")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                if let created = feedTrip.trip.createdAt {
                    Text(created.relativeText)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trip Cover

    private var tripCover: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image
            Group {
                if let urlString = feedTrip.trip.coverImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill().transition(.opacity)
                        case .failure:
                            placeholderGradient
                        case .empty:
                            placeholderGradient.shimmerEffect()
                        @unknown default:
                            placeholderGradient
                        }
                    }
                } else {
                    placeholderGradient
                }
            }
            .frame(height: 200)
            .clipped()

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Trip info
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                Text(feedTrip.trip.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: OuestTheme.Spacing.md) {
                    Label(feedTrip.trip.destination, systemImage: "mappin")
                    if let dates = feedTrip.trip.dateRangeText {
                        Label(dates, systemImage: "calendar")
                    }
                }
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(OuestTheme.Spacing.md)
        }
    }

    private var placeholderGradient: some View {
        let hash = abs(feedTrip.trip.destination.hashValue)
        let colors = OuestTheme.Colors.tripGradients[hash % OuestTheme.Colors.tripGradients.count]
        return ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: OuestTheme.Spacing.xl) {
            // Like button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    likeScale = 1.3
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        likeScale = 1.0
                    }
                }
                onLike()
            } label: {
                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: feedTrip.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(feedTrip.isLiked ? .red : OuestTheme.Colors.textSecondary)
                        .scaleEffect(likeScale)
                    if feedTrip.likeCount > 0 {
                        Text("\(feedTrip.likeCount)")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Comment button
            Button {
                onComment()
            } label: {
                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: "bubble.right")
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    if feedTrip.commentCount > 0 {
                        Text("\(feedTrip.commentCount)")
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Bookmark button
            Button {
                onSave()
            } label: {
                Image(systemName: feedTrip.isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(feedTrip.isSaved ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            // More menu
            Menu {
                Button {
                    onClone()
                } label: {
                    Label("Use as Template", systemImage: "doc.on.doc")
                }

                ShareLink(item: "Check out \"\(feedTrip.trip.title)\" on Ouest!") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
        .font(.body)
    }
}

#Preview {
    NavigationStack {
        FeedTripCardView(
            feedTrip: FeedTrip(
                trip: Trip(
                    id: UUID(), createdBy: UUID(),
                    title: "Summer in Barcelona", destination: "Barcelona, Spain",
                    coverImageUrl: nil,
                    startDate: Date(), endDate: Date().addingTimeInterval(7 * 86400),
                    status: .active, isPublic: true,
                    createdAt: Date().addingTimeInterval(-3600), updatedAt: Date()
                ),
                creatorProfile: Profile(
                    id: UUID(), email: "j@test.com", fullName: "Jane Doe",
                    handle: "janedoe", createdAt: nil
                ),
                memberPreviews: [],
                likeCount: 42,
                commentCount: 7,
                isLiked: false,
                isSaved: false
            ),
            onLike: {},
            onSave: {},
            onComment: {},
            onClone: {}
        )
        .padding()
    }
}
