import PhotosUI
import SwiftUI

struct TripGalleryView: View {
    let trip: Trip
    var canEdit: Bool = true

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var photos: [TripPhoto] = []
    @State private var isLoading = true
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var contentAppeared = false

    // Photo picker
    @State private var selectedItems: [PhotosPickerItem] = []

    // Grid layout: 3 columns
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        Group {
            if isLoading {
                loadingGrid
            } else if photos.isEmpty {
                emptyState
            } else {
                galleryGrid
            }
        }
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(OuestTheme.Colors.brand)
                    }
                }
            }
        }
        .overlay {
            if isUploading {
                uploadOverlay
            }
        }
        .task {
            await loadPhotos()
            withAnimation(OuestTheme.Anim.smooth) {
                contentAppeared = true
            }
        }
        .refreshable {
            await loadPhotos()
        }
        .onChange(of: selectedItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await handlePhotoSelection(items)
                selectedItems = []
            }
        }
    }

    // MARK: - Gallery Grid

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    NavigationLink {
                        PhotoDetailView(
                            photo: photo,
                            canDelete: canDeletePhoto(photo),
                            onDelete: {
                                await deletePhoto(photo)
                            }
                        )
                    } label: {
                        photoCell(photo, index: index)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if canDeletePhoto(photo) {
                            Button(role: .destructive) {
                                Task {
                                    await deletePhoto(photo)
                                    HapticFeedback.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, OuestTheme.Spacing.xxxl)
        }
    }

    private func photoCell(_ photo: TripPhoto, index: Int) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: photo.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(OuestTheme.Colors.surfaceSecondary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(OuestTheme.Colors.textSecondary)
                        }
                default:
                    SkeletonView(height: 100)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()

            // Uploader avatar badge
            if let profile = photo.profile {
                AvatarView(url: profile.avatarUrl, size: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .shadow(radius: 2)
                    .padding(4)
            }
        }
        .fadeSlideIn(isVisible: contentAppeared, delay: Double(index) * 0.03)
    }

    // MARK: - Loading

    private var loadingGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<9, id: \.self) { _ in
                    SkeletonView(height: 100)
                        .aspectRatio(1, contentMode: .fill)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "photo.on.rectangle",
            title: "No Photos Yet",
            message: canEdit
                ? "Start adding photos from your trip — tap the + button to upload."
                : "No photos have been shared for this trip yet."
        )
    }

    // MARK: - Upload Overlay

    private var uploadOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: OuestTheme.Spacing.md) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Uploading photos…")
                    .font(OuestTheme.Typography.caption)
                    .foregroundStyle(.white)
            }
            .padding(OuestTheme.Spacing.xxl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        }
    }

    // MARK: - Data Operations

    private func loadPhotos() async {
        do {
            photos = try await GalleryService.fetchPhotos(tripId: trip.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) async {
        guard let userId = authViewModel.currentUser?.id else { return }

        isUploading = true
        HapticFeedback.light()

        var imageDataList: [(data: Data, caption: String?)] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                imageDataList.append((data: data, caption: nil))
            }
        }

        guard !imageDataList.isEmpty else {
            isUploading = false
            return
        }

        do {
            let newPhotos = try await GalleryService.uploadPhotos(
                tripId: trip.id,
                userId: userId,
                images: imageDataList
            )
            photos.insert(contentsOf: newPhotos, at: 0)
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }

    private func deletePhoto(_ photo: TripPhoto) async {
        do {
            try await GalleryService.deletePhoto(photo)
            photos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func canDeletePhoto(_ photo: TripPhoto) -> Bool {
        guard let userId = authViewModel.currentUser?.id else { return false }
        return photo.uploadedBy == userId || trip.createdBy == userId
    }
}

#Preview {
    NavigationStack {
        TripGalleryView(
            trip: Trip(
                id: UUID(), createdBy: UUID(), title: "Test Trip",
                destination: "Paris", status: .active, isPublic: false,
                createdAt: nil
            )
        )
        .environment(AuthViewModel())
    }
}
