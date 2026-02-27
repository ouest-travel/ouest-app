import SwiftUI

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            if let imageUrl = entry.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    default:
                        SkeletonView(height: 180)
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
                Text(entry.title)
                    .font(OuestTheme.Typography.cardTitle)
                    .lineLimit(2)

                if let content = entry.content, !content.isEmpty {
                    Text(content)
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .lineLimit(3)
                }

                // Footer: mood + location + date
                HStack(spacing: OuestTheme.Spacing.sm) {
                    if let mood = entry.mood {
                        HStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: mood.icon)
                                .font(.system(size: 11))
                            Text(mood.label)
                                .font(OuestTheme.Typography.micro)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(mood.color)
                        .padding(.horizontal, OuestTheme.Spacing.sm)
                        .padding(.vertical, OuestTheme.Spacing.xxs)
                        .background(mood.color.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    if let location = entry.locationName, !location.isEmpty {
                        HStack(spacing: OuestTheme.Spacing.xxs) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .font(OuestTheme.Typography.micro)
                                .lineLimit(1)
                        }
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }

                    Spacer()

                    if let createdAt = entry.createdAt {
                        Text(createdAt.relativeText)
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(OuestTheme.Spacing.lg)
        }
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .shadow(OuestTheme.Shadow.md)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(OuestTheme.Colors.surfaceSecondary)
            .frame(height: 180)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
    }
}
