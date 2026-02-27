import SwiftUI
import PhotosUI

struct AddJournalEntryView: View {
    @Bindable var viewModel: JournalViewModel
    let trip: Trip
    let entry: JournalEntry? // nil = create, non-nil = edit
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoPreview: Image?
    @State private var contentAppeared = false

    private var isEditing: Bool { entry != nil }
    private let contentMaxLength = 5000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    photoSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                    detailsSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.08)

                    dateSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.12)

                    locationSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.16)

                    moodSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.20)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(OuestTheme.Spacing.xl)
            }
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSaving || !viewModel.isFormValid)
                }
            }
            .onAppear {
                if let entry, !isEditing {
                    viewModel.populateFromEntry(entry)
                }
                // Load existing photo preview if editing
                if let imageUrl = entry?.imageUrl, let url = URL(string: imageUrl) {
                    loadRemotePhoto(url)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
            .task {
                withAnimation(OuestTheme.Anim.smooth) {
                    contentAppeared = true
                }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Photo", icon: "camera.fill")

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let photoPreview {
                        photoPreview
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .indigo.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    VStack(spacing: OuestTheme.Spacing.sm) {
                        Image(systemName: photoPreview == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                            .font(.title2)
                            .symbolEffect(.bounce, value: photoPreview != nil)
                        Text(photoPreview == nil ? "Add Photo" : "Change Photo")
                            .font(OuestTheme.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(OuestTheme.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .pressEffect(scale: 0.97)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Details", icon: "pencil.line")

            OuestTextField(text: $viewModel.title, placeholder: "Entry title")
                .textInputAutocapitalization(.words)

            VStack(alignment: .trailing, spacing: OuestTheme.Spacing.xs) {
                TextEditor(text: $viewModel.content)
                    .font(.body)
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(OuestTheme.Spacing.sm)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                    .onChange(of: viewModel.content) { _, newValue in
                        if newValue.count > contentMaxLength {
                            viewModel.content = String(newValue.prefix(contentMaxLength))
                        }
                    }

                Text("\(viewModel.content.count)/\(contentMaxLength)")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(
                        viewModel.content.count > contentMaxLength - 100
                        ? OuestTheme.Colors.warning
                        : OuestTheme.Colors.textSecondary
                    )
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Date", icon: "calendar")

            DatePicker("Entry date", selection: $viewModel.entryDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(OuestTheme.Spacing.md)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Location", icon: "mappin.and.ellipse")

            OuestTextField(text: $viewModel.locationName, placeholder: "e.g. Eiffel Tower, Paris")
                .textInputAutocapitalization(.words)
        }
    }

    // MARK: - Mood Section

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            sectionHeader("Mood", icon: "face.smiling")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OuestTheme.Spacing.sm) {
                ForEach(JournalMood.allCases, id: \.self) { moodOption in
                    let isSelected = viewModel.mood == moodOption

                    Button {
                        HapticFeedback.selection()
                        withAnimation(OuestTheme.Anim.quick) {
                            viewModel.mood = isSelected ? nil : moodOption
                        }
                    } label: {
                        VStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: moodOption.icon)
                                .font(.title3)
                            Text(moodOption.label)
                                .font(OuestTheme.Typography.micro)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OuestTheme.Spacing.md)
                        .foregroundStyle(isSelected ? .white : moodOption.color)
                        .background(
                            isSelected
                            ? AnyShapeStyle(moodOption.color)
                            : AnyShapeStyle(moodOption.color.opacity(0.1))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.brand)
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
        }
    }

    // MARK: - Actions

    private func save() async {
        if let entry {
            if await viewModel.updateEntry(id: entry.id, tripId: trip.id) {
                HapticFeedback.success()
                dismiss()
            } else {
                HapticFeedback.error()
            }
        } else {
            if let _ = await viewModel.createEntry(tripId: trip.id) {
                HapticFeedback.success()
                dismiss()
            } else {
                HapticFeedback.error()
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                viewModel.imageData = data
                if let uiImage = UIImage(data: data) {
                    withAnimation(OuestTheme.Anim.smooth) {
                        photoPreview = Image(uiImage: uiImage)
                    }
                    HapticFeedback.selection()
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to load image"
        }
    }

    private func loadRemotePhoto(_ url: URL) {
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let uiImage = UIImage(data: data) {
                photoPreview = Image(uiImage: uiImage)
            }
        }
    }
}

#Preview {
    AddJournalEntryView(
        viewModel: JournalViewModel(),
        trip: Trip(
            id: UUID(), createdBy: UUID(), title: "Test",
            destination: "Paris", status: .active, isPublic: false,
            createdAt: nil
        ),
        entry: nil
    )
}
