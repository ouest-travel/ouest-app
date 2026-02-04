import SwiftUI

struct ActiveTripCard: View {
    let trip: Trip
    var members: [Profile] = []

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

                // Destination overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.destinationEmoji)
                        .font(.system(size: 32))

                    Text(trip.destination)
                        .font(OuestTheme.Fonts.title3)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                .padding(OuestTheme.Spacing.md)
            }
            .frame(height: 120)
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

                    Text(trip.dateRangeFormatted)
                        .font(OuestTheme.Fonts.subheadline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }

                // Bottom row: Budget + Status
                HStack {
                    // Budget
                    if let budget = trip.budget {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 12))
                            Text(CurrencyFormatter.format(amount: budget, currency: trip.currency))
                                .font(OuestTheme.Fonts.caption)
                        }
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Status badge
                    StatusBadge(status: trip.status)
                }
            }
            .padding(OuestTheme.Spacing.md)
        }
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
        } else {
            return [OuestTheme.Colors.primary, OuestTheme.Colors.indigo]
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
        .background(statusColor.opacity(0.1))
        .cornerRadius(OuestTheme.CornerRadius.small)
    }

    private var statusColor: Color {
        switch status {
        case .planning:
            return OuestTheme.Colors.warning
        case .upcoming:
            return OuestTheme.Colors.primary
        case .active:
            return OuestTheme.Colors.success
        case .completed:
            return OuestTheme.Colors.textSecondary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActiveTripCard(trip: DemoModeManager.demoTrips[0])
        ActiveTripCard(trip: DemoModeManager.demoTrips[1])
        ActiveTripCard(trip: DemoModeManager.demoTrips[2])
    }
    .padding()
    .background(OuestTheme.Colors.background)
}
