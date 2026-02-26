import SwiftUI

struct TripCardView: View {
    let trip: Trip
    var style: CardStyle = .standard
    var members: [TripMemberPreview] = []

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

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
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
        .shadow(OuestTheme.Shadow.lg)
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
        .shadow(OuestTheme.Shadow.md)
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

    /// Generate a consistent gradient based on the destination name
    private var destinationColors: [Color] {
        let hash = abs(trip.destination.hashValue)
        return OuestTheme.Colors.tripGradients[hash % OuestTheme.Colors.tripGradients.count]
    }

    private var statusBadge: some View {
        HStack(spacing: OuestTheme.Spacing.xs) {
            Image(systemName: trip.status.icon)
                .font(.caption2)
            Text(trip.status.label)
                .font(OuestTheme.Typography.micro)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, OuestTheme.Spacing.sm)
        .padding(.vertical, OuestTheme.Spacing.xxs)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.status {
        case .planning: OuestTheme.Colors.planning
        case .active: OuestTheme.Colors.active
        case .completed: OuestTheme.Colors.completed
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
