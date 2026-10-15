import SwiftUI
import PhotosUI
import Supabase

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
    /// Surface for handle-collision + server errors so saveAndFinish can
    /// refuse to advance without silently losing the user's data.
    @State private var onboardingError: String?

    private let totalSteps = 4

    /// Handles must be 3–20 chars, lowercase letters / digits / underscores.
    /// Matches the server-side rule enforced in EditProfileView and the
    /// Supabase handle trigger.
    private static let handleRegex = #"^[a-z0-9_]{3,20}$"#

    /// Core identity fields that MUST be set before a user can leave onboarding.
    /// Full name must be non-blank after trimming. Handle must match the
    /// regex above. These are the fields the rest of the app assumes are
    /// non-nil (profile card, @mentions, follower graph, feed authorship).
    private var isProfileStepValid: Bool {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, !h.isEmpty else { return false }
        return h.range(of: Self.handleRegex, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Skip is only ever allowed on the Interests step. The Profile
            // step (name + handle) is identity, not personalization — the
            // rest of the app assumes those fields exist, so we gate hard
            // instead of letting users bypass. Interests are optional.
            if currentStep == 2 {
                HStack {
                    Spacer()
                    Button("Skip") {
                        HapticFeedback.selection()
                        // Still runs saveAndFinish so name + handle from
                        // step 1 are persisted — we only skip the interest
                        // selection, not the save.
                        Task { await saveAndFinish() }
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
            // Defense in depth: if a swipe gesture advances past the
            // profile step without valid name + handle, snap back.
            .onChange(of: currentStep) { oldValue, newValue in
                if newValue > 1 && !isProfileStepValid {
                    currentStep = 1
                }
            }

            if let onboardingError {
                Text(onboardingError)
                    .font(.caption)
                    .foregroundStyle(OuestTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OuestTheme.Spacing.xxl)
                    .padding(.bottom, OuestTheme.Spacing.sm)
            }

            pageIndicator
                .padding(.bottom, OuestTheme.Spacing.xxl)
        }
        .onAppear {
            // Returning user with an incomplete profile — don't show them
            // the "Welcome" step (step 0), that copy is for brand-new
            // accounts. Jump straight to the Profile step and pre-fill
            // anything they already have so they're only typing the
            // missing fields.
            if let profile = authViewModel.currentUser {
                if fullName.isEmpty { fullName = profile.fullName ?? "" }
                if handle.isEmpty { handle = profile.handle ?? "" }
                if nationality.isEmpty { nationality = profile.nationality ?? "" }
                if currentStep == 0 && (profile.handle ?? "").isEmpty {
                    currentStep = 1
                }
            }
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
                        .textInputAutocapitalization(.words)

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
                    onboardingError = nil
                    withAnimation { currentStep = 2 }
                }
                .disabled(!isProfileStepValid)
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
                .font(.system(size: OuestTheme.Icon.hero))
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
        // Final guard — name + handle must be present before we persist
        // anything or let the user leave onboarding. If someone gestured
        // past step 1, snap them back instead of writing a half-formed
        // profile to the DB.
        guard isProfileStepValid else {
            onboardingError = "Please add your name and a valid handle before continuing."
            withAnimation { currentStep = 1 }
            return
        }

        isSaving = true
        onboardingError = nil
        defer { isSaving = false }

        do {
            // Use session user ID directly — currentUser may be nil for new signups
            // because the DB trigger that creates the profile row hasn't fired yet.
            let userId = try await SupabaseManager.client.auth.session.user.id

            // Upload avatar if selected
            var avatarUrl: String?
            if let data = avatarData {
                avatarUrl = try await StorageService.uploadProfileAvatar(
                    data: data, userId: userId
                )
            }

            let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let trimmedNationality = nationality.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            let payload = UpdateProfilePayload(
                fullName: trimmedName,
                handle: trimmedHandle,
                nationality: trimmedNationality.isEmpty ? nil : trimmedNationality,
                avatarUrl: avatarUrl,
                travelInterests: selectedInterests.isEmpty
                    ? nil
                    : selectedInterests.map(\.rawValue)
            )

            // Update profile directly — don't go through authViewModel.updateProfile()
            // which guards on currentUser?.id and would silently fail.
            let updated: Profile = try await SupabaseManager.client
                .from("profiles")
                .update(payload)
                .eq("id", value: userId)
                .select()
                .single()
                .execute()
                .value
            authViewModel.currentUser = updated
            HapticFeedback.success()
            withAnimation { currentStep = 3 }
        } catch {
            // Postgres 23505 unique_violation surfaces as 'duplicate key' /
            // 'unique constraint' in localizedDescription — the only unique
            // column the user can collide on from this form is `handle`.
            // Same detection style as EditProfileView.applySaveError.
            let desc = error.localizedDescription.lowercased()
            let isHandleTaken = desc.contains("duplicate key")
                || desc.contains("unique constraint")
            onboardingError = isHandleTaken
                ? "That handle is already taken — try another."
                : error.localizedDescription
            HapticFeedback.error()
            withAnimation { currentStep = 1 }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthViewModel())
}
