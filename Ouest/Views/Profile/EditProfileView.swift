import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var fullName = ""
    @State private var handle = ""
    @State private var bio = ""
    @State private var nationality = ""
    @State private var selectedInterests: Set<TravelInterest> = []

    // MARK: - Avatar State

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarPreview: Image?
    @State private var avatarData: Data?

    // MARK: - UI State

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var contentAppeared = false

    private let bioMaxLength = 300

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xxl) {
                    avatarSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0)

                    personalInfoSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.1)

                    bioSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.15)

                    interestsSection
                        .fadeSlideIn(isVisible: contentAppeared, delay: 0.2)

                    if let error = errorMessage {
                        Text(error)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(OuestTheme.Spacing.xl)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving || !isFormValid)
                }
            }
            .onAppear { populateForm() }
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

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            sectionHeader(icon: "camera.fill", title: "Profile Photo")

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let avatarPreview {
                        avatarPreview
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        AvatarView(url: authViewModel.currentUser?.avatarUrl, size: 100)
                    }

                    // Camera badge
                    Circle()
                        .fill(OuestTheme.Colors.brand)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: 4)
                }
            }
        }
    }

    // MARK: - Personal Info Section

    private var personalInfoSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            sectionHeader(icon: "person.fill", title: "Personal Info")

            VStack(spacing: OuestTheme.Spacing.md) {
                OuestTextField(text: $fullName, placeholder: "Full name")

                HStack(spacing: OuestTheme.Spacing.xs) {
                    Text("@")
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .frame(width: 24)

                    TextField("handle", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body)
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .frame(height: 50)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))

                HStack(spacing: OuestTheme.Spacing.xs) {
                    Image(systemName: "flag.fill")
                        .font(.body)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .frame(width: 24)

                    TextField("Country code (e.g. US, GB, FR)", text: $nationality)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body)
                }
                .padding(.horizontal, OuestTheme.Spacing.md)
                .frame(height: 50)
                .background(OuestTheme.Colors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
            }
        }
    }

    // MARK: - Bio Section

    private var bioSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            sectionHeader(icon: "text.quote", title: "Bio")

            VStack(alignment: .trailing, spacing: OuestTheme.Spacing.xs) {
                TextEditor(text: $bio)
                    .font(.body)
                    .frame(minHeight: 80, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(OuestTheme.Spacing.sm)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.sm))
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > bioMaxLength {
                            bio = String(newValue.prefix(bioMaxLength))
                        }
                    }

                Text("\(bio.count)/\(bioMaxLength)")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(
                        bio.count > bioMaxLength - 20
                        ? OuestTheme.Colors.warning
                        : OuestTheme.Colors.textSecondary
                    )
            }
        }
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(spacing: OuestTheme.Spacing.md) {
            sectionHeader(icon: "sparkles", title: "Travel Interests")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OuestTheme.Spacing.sm) {
                ForEach(TravelInterest.allCases, id: \.self) { interest in
                    let isSelected = selectedInterests.contains(interest)

                    Button {
                        HapticFeedback.selection()
                        withAnimation(OuestTheme.Anim.quick) {
                            if isSelected {
                                selectedInterests.remove(interest)
                            } else {
                                selectedInterests.insert(interest)
                            }
                        }
                    } label: {
                        VStack(spacing: OuestTheme.Spacing.xs) {
                            Image(systemName: interest.icon)
                                .font(.title3)
                            Text(interest.label)
                                .font(OuestTheme.Typography.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OuestTheme.Spacing.md)
                        .foregroundStyle(isSelected ? .white : interest.color)
                        .background(
                            isSelected
                            ? AnyShapeStyle(interest.color)
                            : AnyShapeStyle(interest.color.opacity(0.1))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(OuestTheme.Colors.brand)
                .font(.subheadline)
            Text(title)
                .font(OuestTheme.Typography.sectionTitle)
            Spacer()
        }
    }

    // MARK: - Populate Form

    private func populateForm() {
        guard let profile = authViewModel.currentUser else { return }
        fullName = profile.fullName ?? ""
        handle = profile.handle ?? ""
        bio = profile.bio ?? ""
        nationality = profile.nationality ?? ""

        if let interests = profile.travelInterests {
            selectedInterests = Set(interests.compactMap { TravelInterest(rawValue: $0) })
        }
    }

    // MARK: - Load Photo

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                avatarData = data
                if let uiImage = UIImage(data: data) {
                    avatarPreview = Image(uiImage: uiImage)
                }
            }
        } catch {
            errorMessage = "Failed to load image"
        }
    }

    // MARK: - Save Profile

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            // Upload avatar if changed
            var avatarUrl = authViewModel.currentUser?.avatarUrl
            if let data = avatarData, let userId = authViewModel.currentUser?.id {
                avatarUrl = try await StorageService.uploadProfileAvatar(data: data, userId: userId)
            }

            let payload = UpdateProfilePayload(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                handle: handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().isEmpty
                    ? nil
                    : handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                nationality: nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : nationality.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                avatarUrl: avatarUrl,
                travelInterests: selectedInterests.map(\.rawValue)
            )

            try await authViewModel.updateProfile(payload)
            HapticFeedback.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HapticFeedback.error()
        }

        isSaving = false
    }
}

#Preview {
    EditProfileView()
        .environment(AuthViewModel())
}
