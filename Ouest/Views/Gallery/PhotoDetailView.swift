import SwiftUI

struct PhotoDetailView: View {
    let photo: TripPhoto
    var canDelete: Bool = false
    var onDelete: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xl) {
                // Full-size photo
                AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    case .failure:
                        placeholder
                    default:
                        SkeletonView(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)

                // Caption
                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, OuestTheme.Spacing.xl)
                }

                // Uploader info
                uploaderSection
                    .padding(.horizontal, OuestTheme.Spacing.xl)
            }
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Delete photo")
                }
            }
        }
        .alert("Delete Photo", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete?()
                    HapticFeedback.success()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently removed from the gallery.")
        }
    }

    // MARK: - Uploader Section

    private var uploaderSection: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            if let profileId = photo.profile?.id {
                NavigationLink {
                    UserProfileView(userId: profileId)
                } label: {
                    HStack(spacing: OuestTheme.Spacing.sm) {
                        AvatarView(url: photo.profile?.avatarUrl, size: 32)
                        uploaderInfo
                    }
                }
                .buttonStyle(.plain)
            } else {
                AvatarView(url: photo.profile?.avatarUrl, size: 32)
                uploaderInfo
            }

            Spacer()
        }
    }

    private var uploaderInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(photo.profile?.fullName ?? "Traveler")
                .font(OuestTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(OuestTheme.Colors.textPrimary)

            if let date = photo.createdAt {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
            .fill(OuestTheme.Colors.surfaceSecondary)
            .frame(height: 300)
            .overlay {
                VStack(spacing: OuestTheme.Spacing.sm) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Text("Failed to load photo")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
            }
    }
}

#Preview {
    NavigationStack {
        PhotoDetailView(
            photo: TripPhoto(
                id: UUID(),
                tripId: UUID(),
                uploadedBy: UUID(),
                imageUrl: "https://example.com/photo.jpg",
                caption: "Beautiful sunset at the beach",
                createdAt: Date()
            ),
            canDelete: true
        )
    }
}
