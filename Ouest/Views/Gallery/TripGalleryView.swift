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
    @State private var infoMessage: String?            // non-fatal toast (partial success)
    @State private var uploadProgress: (done: Int, total: Int) = (0, 0)
    @State private var contentAppeared = false

    /// Per-photo reload keys — bumping a photo's key re-runs its AsyncImage fetch.
    @State private var photoReloadKeys: [UUID: UUID] = [:]

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
        .alert("Something went wrong", isPresented: errorAlertBinding, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { msg in
            Text(msg)
        }
        .overlay(alignment: .top) {
            if let info = infoMessage {
                infoToast(info)
                    .padding(.top, OuestTheme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Bindings & Toasts

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func infoToast(_ message: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(OuestTheme.Colors.brand)
            Text(message)
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
                .lineLimit(2)
        }
        .padding(.horizontal, OuestTheme.Spacing.md)
        .padding(.vertical, OuestTheme.Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(OuestTheme.Shadow.md)
        .padding(.horizontal, OuestTheme.Spacing.lg)
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
                    failureTile(for: photo)
                default:
                    SkeletonView(height: 100)
                }
            }
            // Bumping this key forces AsyncImage to re-fetch.
            .id(photoReloadKeys[photo.id] ?? photo.id)
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

    /// Tappable failure tile — taps trigger a re-fetch of the AsyncImage.
    private func failureTile(for photo: TripPhoto) -> some View {
        Button {
            HapticFeedback.light()
            // New UUID = new identity = AsyncImage re-fetch
            photoReloadKeys[photo.id] = UUID()
        } label: {
            Rectangle()
                .fill(OuestTheme.Colors.surfaceSecondary)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                            .foregroundStyle(OuestTheme.Colors.brand)
                        Text("Retry")
                            .font(OuestTheme.Typography.micro)
                            .foregroundStyle(OuestTheme.Colors.textSecondary)
                    }
                }
        }
        .buttonStyle(.plain)
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
                if uploadProgress.total > 0 {
                    // Determinate progress when we know totals
                    ProgressView(value: Double(uploadProgress.done), total: Double(uploadProgress.total))
                        .tint(.white)
                        .frame(width: 140)
                    Text("Uploading \(uploadProgress.done) of \(uploadProgress.total)…")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(.white)
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Preparing photos…")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(.white)
                }
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
        uploadProgress = (0, 0)
        HapticFeedback.light()

        // 1. Load the bytes for each picked item, tracking individual load failures.
        var imageDataList: [(data: Data, caption: String?)] = []
        var loadFailures = 0

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    imageDataList.append((data: data, caption: nil))
                } else {
                    loadFailures += 1
                }
            } catch {
                loadFailures += 1
            }
        }

        // 2. If everything failed to load, bail with an error.
        guard !imageDataList.isEmpty else {
            isUploading = false
            errorMessage = "Couldn't read \(items.count == 1 ? "the selected photo" : "any of the selected photos") from your library. Please try a different selection."
            HapticFeedback.error()
            return
        }

        // 3. Upload in parallel with partial-success handling.
        uploadProgress = (0, imageDataList.count)
        let result = await GalleryService.uploadPhotos(
            tripId: trip.id,
            userId: userId,
            images: imageDataList,
            onProgress: { done in
                Task { @MainActor in
                    uploadProgress.done = done
                }
            }
        )

        // 4. Insert successful uploads at the top of the grid.
        if !result.uploaded.isEmpty {
            photos.insert(contentsOf: result.uploaded, at: 0)
        }

        // 5. Surface outcomes to the user.
        let totalFailed = result.failures.count + loadFailures
        let totalAttempted = imageDataList.count + loadFailures

        if totalFailed == 0 {
            HapticFeedback.success()
        } else if result.uploaded.isEmpty {
            // Everything failed — show the first error as the alert message.
            let detail = result.failures.first?.localizedDescription
                ?? "We couldn't upload the photo. Please try again."
            errorMessage = detail
            HapticFeedback.error()
        } else {
            // Partial — non-fatal toast.
            infoMessage = "\(result.uploaded.count) of \(totalAttempted) photos uploaded. \(totalFailed) failed — try again later."
            HapticFeedback.success()
            // Auto-dismiss the toast after a few seconds.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                withAnimation(OuestTheme.Anim.smooth) {
                    infoMessage = nil
                }
            }
        }

        isUploading = false
        uploadProgress = (0, 0)
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
