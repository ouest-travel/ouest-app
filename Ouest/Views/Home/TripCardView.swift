import SwiftUI

struct TripCardView: View {
    let trip: Trip
    var style: CardStyle = .standard

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

            VStack(alignment: .leading, spacing: 6) {
                if let days = trip.daysUntilStart, days >= 0 {
                    Text(days == 0 ? "Today!" : "\(days) day\(days == 1 ? "" : "s") away")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Text(trip.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label(trip.destination, systemImage: "mappin")
                    if let dates = trip.dateRangeText {
                        Label(dates, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Standard List Card

    private var standardCard: some View {
        HStack(spacing: 14) {
            // Small cover thumbnail
            coverImage(height: 80)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let dates = trip.dateRangeText {
                    Text(dates)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                statusBadge
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    // MARK: - Shared Components

    private func coverImage(height: CGFloat) -> some View {
        Group {
            if let urlString = trip.coverImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderGradient
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
        let palettes: [[Color]] = [
            [.blue, .purple],
            [.teal, .blue],
            [.orange, .pink],
            [.green, .teal],
            [.indigo, .blue],
            [.pink, .orange],
            [.purple, .indigo],
            [.mint, .green],
        ]
        return palettes[hash % palettes.count]
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trip.status.icon)
                .font(.caption2)
            Text(trip.status.label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.status {
        case .planning: .blue
        case .active: .green
        case .completed: .secondary
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
            createdAt: Date(),
            updatedAt: Date()
        ),
        style: .standard
    )
    .padding()
}
