import SwiftUI
import MapKit

struct JournalEntryDetailView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                if let imageUrl = entry.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipped()
                        case .failure:
                            imagePlaceholder
                        default:
                            SkeletonView(height: 280)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: OuestTheme.Spacing.lg) {
                    // Title + Date
                    VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                        Text(entry.title)
                            .font(OuestTheme.Typography.screenTitle)

                        HStack(spacing: OuestTheme.Spacing.md) {
                            if let date = entry.createdAt {
                                Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                                    .font(OuestTheme.Typography.caption)
                                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                            }
                        }
                    }

                    // Mood badge
                    if let mood = entry.mood {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: mood.icon)
                                .font(.system(size: 14))
                            Text(mood.label)
                                .font(OuestTheme.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(mood.color)
                        .padding(.horizontal, OuestTheme.Spacing.md)
                        .padding(.vertical, OuestTheme.Spacing.sm)
                        .background(mood.color.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    // Location
                    if let location = entry.locationName, !location.isEmpty {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(OuestTheme.Colors.brand)
                            Text(location)
                                .font(.subheadline)
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                        }
                    }

                    // Content
                    if let content = entry.content, !content.isEmpty {
                        Text(content)
                            .font(.body)
                            .foregroundStyle(OuestTheme.Colors.textPrimary)
                            .lineSpacing(4)
                    }

                    // Mini map
                    if let lat = entry.latitude, let lng = entry.longitude {
                        miniMap(latitude: lat, longitude: lng)
                    }
                }
                .padding(OuestTheme.Spacing.xl)
            }
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Mini Map

    private func miniMap(latitude: Double, longitude: Double) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return Map {
            Marker(entry.locationName ?? entry.title, coordinate: coordinate)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .allowsHitTesting(false)
    }

    // MARK: - Placeholder

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(OuestTheme.Colors.surfaceSecondary)
            .frame(height: 280)
            .overlay {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
    }
}

#Preview {
    NavigationStack {
        JournalEntryDetailView(
            entry: JournalEntry(
                tripId: UUID(),
                title: "A Beautiful Morning in Montmartre",
                content: "Woke up early and wandered through the charming cobblestone streets of Montmartre. The morning light bathed everything in a warm golden glow. Found a tiny bakery tucked away on a side street and had the most incredible croissant and espresso.\n\nThe view from Sacre-Coeur was breathtaking — you could see the entire city stretching out below. Watched street artists set up their easels and start painting.\n\nDefinitely one of the highlights of the trip so far.",
                imageUrl: nil,
                locationName: "Montmartre, Paris",
                latitude: 48.8867,
                longitude: 2.3431,
                mood: .happy,
                createdBy: UUID(),
                createdAt: Date()
            )
        )
    }
}
