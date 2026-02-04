import SwiftUI

struct ActiveTripCard: View {
    let trip: Trip
    var members: [Profile] = []
    var spentAmount: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image / Gradient Header
            ZStack(alignment: .bottomLeading) {
                if let coverImage = trip.coverImage, let url = URL(string: coverImage) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            gradientHeader
                        }
                    }
                } else {
                    gradientHeader
                }

                // Status overlay (top right)
                VStack {
                    HStack {
                        Spacer()
                        StatusBadge(status: trip.status)
                            .padding(OuestTheme.Spacing.sm)
                    }
                    Spacer()
                }

                // Destination overlay
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.destinationEmoji)
                            .font(.system(size: 32))

                        Text(trip.destination)
                            .font(OuestTheme.Fonts.title3)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }

                    Spacer()

                    // Countdown badge for upcoming trips
                    if let daysUntil = trip.daysUntilStart, daysUntil > 0, trip.status == .upcoming {
                        VStack(spacing: 2) {
                            Text("\(daysUntil)")
                                .font(OuestTheme.Fonts.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            Text("days")
                                .font(OuestTheme.Fonts.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, OuestTheme.Spacing.sm)
                        .padding(.vertical, OuestTheme.Spacing.xs)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(OuestTheme.CornerRadius.medium)
                    }
                }
                .padding(OuestTheme.Spacing.md)
            }
            .frame(height: 130)
            .clipped()

            // Trip Details
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                // Trip name
                Text(trip.name)
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)
                    .lineLimit(1)

                // Date range
                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(OuestTheme.Colors.textSecondary)

                    Text(trip.formattedDateRange)
                        .font(OuestTheme.Fonts.subheadline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }

                // Budget progress bar (if budget is set)
                if let budget = trip.budget, budget > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(CurrencyFormatter.format(amount: spentAmount, currency: trip.currency))
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.text)

                            Spacer()

                            Text("of \(CurrencyFormatter.format(amount: budget, currency: trip.currency))")
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.textSecondary)
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(OuestTheme.Colors.inputBackground)
                                    .frame(height: 6)

                                Capsule()
                                    .fill(progressGradient)
                                    .frame(width: geometry.size.width * min(budgetProgress, 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }

                // Bottom row: Members + Info
                HStack {
                    // Member avatars
                    if !members.isEmpty {
                        MemberAvatarsStack(profiles: members, maxVisible: 3)
                    }

                    Spacer()

                    // Quick stats
                    HStack(spacing: OuestTheme.Spacing.md) {
                        if !members.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 12))
                                Text("\(members.count)")
                                    .font(OuestTheme.Fonts.caption)
                            }
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(OuestTheme.Spacing.md)
        }
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var budgetProgress: Double {
        guard let budget = trip.budget, budget > 0 else { return 0 }
        return Double(truncating: (spentAmount / budget) as NSDecimalNumber)
    }

    private var progressGradient: LinearGradient {
        if budgetProgress > 0.9 {
            return LinearGradient(colors: [OuestTheme.Colors.error, OuestTheme.Colors.error.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else if budgetProgress > 0.7 {
            return LinearGradient(colors: [OuestTheme.Colors.warning, OuestTheme.Colors.warning.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else {
            return OuestTheme.Gradients.primary
        }
    }

    private var gradientHeader: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        // Different gradients based on destination
        let destination = trip.destination.lowercased()

        if destination.contains("japan") || destination.contains("tokyo") {
            return [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]
        } else if destination.contains("france") || destination.contains("paris") {
            return [Color(hex: "667eea"), Color(hex: "764ba2")]
        } else if destination.contains("spain") || destination.contains("barcelona") {
            return [Color(hex: "f093fb"), Color(hex: "f5576c")]
        } else if destination.contains("italy") || destination.contains("rome") {
            return [Color(hex: "11998e"), Color(hex: "38ef7d")]
        } else if destination.contains("uk") || destination.contains("london") {
            return [Color(hex: "373B44"), Color(hex: "4286f4")]
        } else if destination.contains("usa") || destination.contains("new york") {
            return [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
        } else {
            return [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo]
        }
    }
}

// MARK: - Member Avatars Stack

struct MemberAvatarsStack: View {
    let profiles: [Profile]
    var maxVisible: Int = 3
    var size: OuestAvatarSize = .small

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(profiles.prefix(maxVisible).enumerated()), id: \.element.id) { index, profile in
                OuestAvatar(profile, size: size)
                    .overlay(
                        Circle()
                            .stroke(OuestTheme.Colors.cardBackground, lineWidth: 2)
                    )
                    .zIndex(Double(maxVisible - index))
            }

            if profiles.count > maxVisible {
                ZStack {
                    Circle()
                        .fill(OuestTheme.Colors.inputBackground)
                        .frame(width: size.dimension, height: size.dimension)

                    Text("+\(profiles.count - maxVisible)")
                        .font(OuestTheme.Fonts.caption2)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }
                .overlay(
                    Circle()
                        .stroke(OuestTheme.Colors.cardBackground, lineWidth: 2)
                )
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: TripStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(status.displayName)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusBackground)
        .cornerRadius(OuestTheme.CornerRadius.small)
    }

    private var statusColor: Color {
        switch status {
        case .planning:
            return OuestTheme.Colors.warning
        case .upcoming:
            return OuestTheme.Colors.Brand.coral
        case .active:
            return OuestTheme.Colors.success
        case .completed:
            return OuestTheme.Colors.textSecondary
        }
    }

    private var statusBackground: Color {
        switch status {
        case .planning:
            return OuestTheme.Colors.warning.opacity(0.15)
        case .upcoming:
            return OuestTheme.Colors.Brand.coral.opacity(0.15)
        case .active:
            return OuestTheme.Colors.success.opacity(0.15)
        case .completed:
            return OuestTheme.Colors.textSecondary.opacity(0.15)
        }
    }
}

// MARK: - Compact Trip Card (for lists)

struct CompactTripCard: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            // Emoji / Image
            ZStack {
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: [OuestTheme.Colors.Brand.blue, OuestTheme.Colors.Brand.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text(trip.destinationEmoji)
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(OuestTheme.Fonts.headline)
                    .foregroundColor(OuestTheme.Colors.text)
                    .lineLimit(1)

                Text(trip.destination)
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.textSecondary)
                    .lineLimit(1)

                Text(trip.formattedDateRange)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(OuestTheme.Colors.textTertiary)
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.medium)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ActiveTripCard(
                trip: DemoModeManager.demoTrips[0],
                members: DemoModeManager.demoMembers,
                spentAmount: 839
            )

            ActiveTripCard(
                trip: DemoModeManager.demoTrips[1],
                members: Array(DemoModeManager.demoMembers.prefix(2)),
                spentAmount: 0
            )

            ActiveTripCard(
                trip: DemoModeManager.demoTrips[2],
                members: DemoModeManager.demoMembers,
                spentAmount: 1800
            )

            CompactTripCard(trip: DemoModeManager.demoTrips[0])
        }
        .padding()
    }
    .background(OuestTheme.Colors.background)
}
