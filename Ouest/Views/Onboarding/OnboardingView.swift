import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    // MARK: - Step State

    @State private var currentStep = 0

    // MARK: - Profile State

    @State private var fullName = ""
    @State private var handle = ""
    @State private var nationality = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarPreview: Image?
    @State private var avatarData: Data?

    // MARK: - Interests State

    @State private var selectedInterests: Set<TravelInterest> = []

    // MARK: - UI State

    @State private var isSaving = false
    @State private var appeared = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Skip button — visible on profile & interests steps
            if currentStep == 1 || currentStep == 2 {
                HStack {
                    Spacer()
                    Button("Skip") {
                        HapticFeedback.selection()
                        authViewModel.completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .padding(.horizontal, OuestTheme.Spacing.xxl)
                .padding(.top, OuestTheme.Spacing.md)
            }

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                profileStep.tag(1)
                interestsStep.tag(2)
                completionStep.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(OuestTheme.Anim.smooth, value: currentStep)

            pageIndicator
                .padding(.bottom, OuestTheme.Spacing.xxl)
        }
        .onAppear {
            withAnimation(OuestTheme.Anim.smooth) {
                appeared = true
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: OuestTheme.Spacing.xxxl) {
            Spacer()

            Image("OuestLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl))
                .bouncyAppear(isVisible: appeared, delay: 0)

            VStack(spacing: OuestTheme.Spacing.sm) {
                Text("Welcome to Ouest!")
                    .font(OuestTheme.Typography.heroTitle)
                    .multilineTextAlignment(.center)

                Text("Let's set up your profile so your travel crew can find you")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .fadeSlideIn(isVisible: appeared, delay: 0.15)

            OuestButton(title: "Let's Go") {
                HapticFeedback.light()
                withAnimation { currentStep = 1 }
            }
            .fadeSlideIn(isVisible: appeared, delay: 0.3)

            Spacer()
        }
        .padding(.horizontal, OuestTheme.Spacing.xxl)
    }

    // MARK: - Step 1: Profile Info

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xxl) {
                VStack(spacing: OuestTheme.Spacing.sm) {
                    Text("Your Profile")
                        .font(OuestTheme.Typography.screenTitle)

                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .padding(.top, OuestTheme.Spacing.xxxl)

                // Avatar picker
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

                if avatarPreview != nil {
                    Button(role: .destructive) {
                        HapticFeedback.selection()
                        withAnimation(OuestTheme.Anim.quick) {
                            avatarPreview = nil
                            avatarData = nil
                            selectedPhoto = nil
                        }
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                            .font(OuestTheme.Typography.caption)
                    }
                }

                VStack(spacing: OuestTheme.Spacing.md) {
                    // Full name field
                    OuestTextField(text: $fullName, placeholder: "Full name")

                    // Handle field
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

                    // Nationality field
                    NationalityPickerField(selectedCode: $nationality)
                }

                Spacer(minLength: OuestTheme.Spacing.xxxl)

                OuestButton(title: "Continue") {
                    HapticFeedback.light()
                    withAnimation { currentStep = 2 }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xxl)
            .padding(.bottom, OuestTheme.Spacing.xxl)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadPhoto(newItem) }
        }
    }

    // MARK: - Step 2: Travel Interests

    private var interestsStep: some View {
        ScrollView {
            VStack(spacing: OuestTheme.Spacing.xxl) {
                VStack(spacing: OuestTheme.Spacing.sm) {
                    Text("Travel Interests")
                        .font(OuestTheme.Typography.screenTitle)

                    Text("Pick what excites you")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .padding(.top, OuestTheme.Spacing.xxxl)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
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

                Spacer(minLength: OuestTheme.Spacing.xxxl)

                OuestButton(title: "Continue", isLoading: isSaving) {
                    Task { await saveAndFinish() }
                }
            }
            .padding(.horizontal, OuestTheme.Spacing.xxl)
            .padding(.bottom, OuestTheme.Spacing.xxl)
        }
    }

    // MARK: - Step 3: Completion

    private var completionStep: some View {
        VStack(spacing: OuestTheme.Spacing.xxxl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(OuestTheme.Colors.success)

            VStack(spacing: OuestTheme.Spacing.sm) {
                Text("You're All Set!")
                    .font(OuestTheme.Typography.heroTitle)

                Text("Time to plan your first adventure")
                    .font(.subheadline)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            OuestButton(title: "Start Exploring") {
                HapticFeedback.success()
                authViewModel.completeOnboarding()
            }

            Spacer()
        }
        .padding(.horizontal, OuestTheme.Spacing.xxl)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentStep
                            ? OuestTheme.Colors.brand
                            : OuestTheme.Colors.surfaceTertiary
                    )
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(OuestTheme.Anim.quick, value: currentStep)
            }
        }
    }

    // MARK: - Photo Loading

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
            // Silently fail — user can update avatar later from profile
        }
    }

    // MARK: - Save & Finish

    private func saveAndFinish() async {
        isSaving = true
        defer { isSaving = false }

        do {
            // Upload avatar if selected
            var avatarUrl: String?
            if let data = avatarData, let userId = authViewModel.currentUser?.id {
                avatarUrl = try await StorageService.uploadProfileAvatar(
                    data: data, userId: userId
                )
            }

            let payload = UpdateProfilePayload(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                handle: handle.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased().isEmpty
                    ? nil
                    : handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                nationality: nationality.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                    ? nil
                    : nationality.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                avatarUrl: avatarUrl,
                travelInterests: selectedInterests.isEmpty
                    ? nil
                    : selectedInterests.map(\.rawValue)
            )

            try await authViewModel.updateProfile(payload)
            HapticFeedback.success()
        } catch {
            // On error, still advance — user can edit profile later
        }

        withAnimation { currentStep = 3 }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthViewModel())
}
