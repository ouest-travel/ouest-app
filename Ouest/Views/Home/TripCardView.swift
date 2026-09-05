import SwiftUI

struct TripCardView: View {
    let trip: Trip
    var style: CardStyle = .standard
    var members: [TripMemberPreview] = []

    /// Namespace for the iOS 18 zoom transition into `TripDetailView`.
    /// Optional so previews and any callers that don't set up the namespace
    /// keep working — the modifier is only applied when a namespace is given.
    var namespace: Namespace.ID? = nil

    enum CardStyle {
        case standard   // Regular list card
        case featured   // Hero card for upcoming trip
    }

    var body: some View {
        Group {
            switch style {
            case .featured: featuredCard
            case .standard: standardCard
            }
        }
    }

    // MARK: - Featured (Hero) Card

    private var featuredCard: some View {
        ZStack(alignment: .bottomLeading) {
            coverImage(height: 220)

            // Gradient overlay (75% deep navy)
            LinearGradient(
                colors: [.clear, OuestTheme.Colors.deepNavy.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if let days = trip.daysUntilStart, days >= 0 {
                        Text(days == 0 ? "Today!" : "\(days) day\(days == 1 ? "" : "s") away")
                            .font(OuestTheme.Typography.micro)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, OuestTheme.Spacing.xs)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .pulseEffect(isActive: days == 0)
                    }

                    Text(trip.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    HStack(spacing: OuestTheme.Spacing.md) {
                        Label(trip.destination, systemImage: "mappin")
                        if let dates = trip.dateRangeText {
                            Label(dates, systemImage: "calendar")
                        }
                    }
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Member avatar stack (featured)
                if !members.isEmpty {
                    memberAvatarStack(size: 28, maxVisible: 4, bordered: true)
                }
            }
            .padding(OuestTheme.Spacing.lg)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
        .ouestElevation(.lg)
        .zoomSource(id: trip.id, in: namespace)
    }

    // MARK: - Standard List Card

    private var standardCard: some View {
        HStack(spacing: 14) {
            // Small cover thumbnail
            coverImage(height: 80)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xs) {
                Text(trip.title)
                    .font(OuestTheme.Typography.cardTitle)
                    .lineLimit(1)

                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                if let dates = trip.dateRangeText {
                    Text(dates)
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }

                HStack {
                    statusBadge

                    Spacer()

                    // Member avatar stack (standard)
                    if !members.isEmpty {
                        memberAvatarStack(size: 22, maxVisible: 3, bordered: false)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .ouestElevation(.md)
        .zoomSource(id: trip.id, in: namespace)
    }

    // MARK: - Member Avatar Stack

    private func memberAvatarStack(size: CGFloat, maxVisible: Int, bordered: Bool) -> some View {
        let visible = Array(members.prefix(maxVisible))
        let overflow = members.count - maxVisible

        return HStack(spacing: -(size * 0.3)) {
            ForEach(visible) { member in
                AvatarView(url: member.profile?.avatarUrl, size: size)
                    .overlay {
                        if bordered {
                            Circle().stroke(.white.opacity(0.8), lineWidth: 1.5)
                        }
                    }
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(bordered ? .white : OuestTheme.Colors.textSecondary)
                    .frame(width: size, height: size)
                    .background {
                        if bordered {
                            Circle().fill(.ultraThinMaterial)
                        } else {
                            Circle().fill(OuestTheme.Colors.surfaceSecondary)
                        }
                    }
                    .clipShape(Circle())
                    .overlay {
                        if bordered {
                            Circle().stroke(.white.opacity(0.8), lineWidth: 1.5)
                        }
                    }
            }
        }
    }

    // MARK: - Shared Components

    private func coverImage(height: CGFloat) -> some View {
        Group {
            if let urlString = trip.coverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        placeholderGradient
                    case .empty:
                        placeholderGradient
                            .shimmerEffect()
                    @unknown default:
                        placeholderGradient
                    }
                }
            } else {
                placeholderGradient
            }
        }
        // maxWidth: .infinity prevents a panoramic cover image from forcing
        // the cell wider than its proposed width. .scaledToFill() preserves
        // aspect ratio at the given height, so a wide image would otherwise
        // have an intrinsic width larger than the row.
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var placeholderGradient: some View {
        ZStack {
            LinearGradient(
                colors: destinationColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    /// Generate a consistent gradient based on the destination name.
    ///
    /// Uses FNV-1a over the destination's UTF-8 bytes so the mapping is stable
    /// across process launches. `String.hashValue` is seeded per process on
    /// Swift, which meant a cover-less trip would change gradient every cold
    /// start — jarring, and one of the bugs called out in the design brief.
    private var destinationColors: [Color] {
        let bucket = Self.fnv1a(trip.destination) % UInt64(OuestTheme.Colors.tripGradients.count)
        return OuestTheme.Colors.tripGradients[Int(bucket)]
    }

    /// 64-bit FNV-1a — stable, tiny, no dependencies. We only need a well-
    /// distributed bucket assignment, not a cryptographic hash.
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    private var statusBadge: some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            Image(systemName: trip.status.icon)
                .font(.caption2)
            Text(trip.status.label)
                .font(OuestTheme.Typography.micro)
        }
        .foregroundStyle(statusStyle.ink)
        .padding(.horizontal, OuestTheme.Spacing.sm)
        .padding(.vertical, OuestTheme.Spacing.xxs)
        .background(statusStyle.tint)
        .clipShape(Capsule())
    }

    private var statusStyle: OuestTheme.StatusStyle {
        switch trip.status {
        case .planning: .planning
        case .active: .active
        case .completed: .completed
        }
    }
}

#Preview("Featured") {
    TripCardView(
        trip: Trip(
            id: UUID(),
            createdBy: UUID(),
            title: "Summer in Barcelona",
            destination: "Barcelona, Spain",
            description: "Beach, tapas, and Gaudi!",
            coverImageUrl: nil,
            startDate: Date().addingTimeInterval(14 * 86400),
            endDate: Date().addingTimeInterval(21 * 86400),
            status: .planning,
            isPublic: false,
            budget: nil,
            currency: nil,
            votingEnabled: nil,
            tags: nil,
            countryCodes: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        style: .featured
    )
    .padding()
}

#Preview("Standard") {
    TripCardView(
        trip: Trip(
            id: UUID(),
            createdBy: UUID(),
            title: "Tokyo Adventure",
            destination: "Tokyo, Japan",
            description: nil,
            coverImageUrl: nil,
            startDate: Date().addingTimeInterval(30 * 86400),
            endDate: Date().addingTimeInterval(37 * 86400),
            status: .planning,
            isPublic: true,
            budget: 3000,
            currency: "USD",
            votingEnabled: nil,
            tags: nil,
            countryCodes: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        style: .standard
    )
    .padding()
}
