import SwiftUI

/// AI-powered itinerary generator.
///
/// User picks one or more vibes, an optional budget level, then taps Generate.
/// The Edge Function calls Claude, populates `itinerary_days` + `itinerary_activities`,
/// and we re-fetch the itinerary in the parent ViewModel.
struct AIGenerateView: View {

    let trip: Trip
    @Bindable var viewModel: ItineraryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var selectedVibes: Set<TripVibe> = []
    @State private var selectedBudget: TripBudgetLevel = .moderate
    @State private var appeared = false
    @State private var prefilledFromProfile = false

    private var canGenerate: Bool {
        !selectedVibes.isEmpty
            && trip.startDate != nil
            && trip.endDate != nil
            && !viewModel.isGeneratingAI
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGeneratingAI {
                    loadingView
                } else {
                    formView
                }
            }
            .navigationTitle("AI Generate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isGeneratingAI)
                }
            }
            .alert(
                "Couldn't generate itinerary",
                isPresented: aiErrorBinding,
                presenting: viewModel.aiError
            ) { _ in
                Button("OK", role: .cancel) { viewModel.aiError = nil }
            } message: { msg in
                Text(msg)
            }
            .onAppear {
                prefillFromProfileIfNeeded()
                withAnimation(OuestTheme.Anim.smooth) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: OuestTheme.Spacing.xxl) {
                header

                tripSummaryCard

                vibesSection

                budgetSection

                Spacer(minLength: OuestTheme.Spacing.md)

                generateButton

                fineprint
            }
            .padding(.horizontal, OuestTheme.Spacing.lg)
            .padding(.vertical, OuestTheme.Spacing.lg)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            HStack(spacing: OuestTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                Text("Skip the blank page")
                    .font(OuestTheme.Typography.screenTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
            }
            Text("Tell us your vibe and we'll generate a complete day-by-day plan for \(trip.destination).")
                .font(.subheadline)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
        }
        .fadeSlideIn(isVisible: appeared, delay: 0)
    }

    private var tripSummaryCard: some View {
        HStack(spacing: OuestTheme.Spacing.md) {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundStyle(OuestTheme.Colors.brand)
                .frame(width: 40, height: 40)
                .background(OuestTheme.Colors.brandLight)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.destination)
                    .font(OuestTheme.Typography.cardTitle)
                    .foregroundStyle(OuestTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let start = trip.startDate, let end = trip.endDate {
                    Text("\(start.formatted_MMMd) – \(end.formatted_MMMdyyyy)")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                } else {
                    Text("Trip dates required")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.error)
                }
            }

            Spacer()
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .fadeSlideIn(isVisible: appeared, delay: 0.05)
    }

    // MARK: - Vibes

    private var vibesSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Text("What's the vibe?")
                    .font(OuestTheme.Typography.sectionTitle)
                Text("(pick at least one)")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                Spacer()
                if didPrefillFromProfile {
                    Label("From your profile", systemImage: "person.crop.circle.badge.checkmark")
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.brand)
                        .labelStyle(.titleAndIcon)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(TripVibe.allCases) { vibe in
                    vibeChip(vibe)
                }
            }
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.1)
    }

    /// Whether any vibes/budget were pre-filled from the user's onboarding interests.
    private var didPrefillFromProfile: Bool {
        let interests = authViewModel.currentUser?.travelInterests ?? []
        return prefilledFromProfile && !interests.compactMap(TripVibe.fromTravelInterest).isEmpty
    }

    private func vibeChip(_ vibe: TripVibe) -> some View {
        let isSelected = selectedVibes.contains(vibe)

        return Button {
            HapticFeedback.selection()
            withAnimation(OuestTheme.Anim.quick) {
                if isSelected {
                    selectedVibes.remove(vibe)
                } else {
                    selectedVibes.insert(vibe)
                }
            }
        } label: {
            HStack(spacing: OuestTheme.Spacing.xs) {
                Image(systemName: vibe.icon)
                    .font(.caption)
                Text(vibe.label)
                    .font(OuestTheme.Typography.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, OuestTheme.Spacing.md)
            .padding(.vertical, OuestTheme.Spacing.sm)
            .foregroundStyle(isSelected ? .white : OuestTheme.Colors.textPrimary)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(OuestTheme.Colors.brandGradient) : AnyShapeStyle(OuestTheme.Colors.surfaceSecondary))
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : OuestTheme.Colors.textSecondary.opacity(0.2),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Budget

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.md) {
            Text("Budget level")
                .font(OuestTheme.Typography.sectionTitle)

            VStack(spacing: OuestTheme.Spacing.sm) {
                ForEach(TripBudgetLevel.allCases) { level in
                    budgetRow(level)
                }
            }
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.15)
    }

    private func budgetRow(_ level: TripBudgetLevel) -> some View {
        let isSelected = selectedBudget == level

        return Button {
            HapticFeedback.selection()
            withAnimation(OuestTheme.Anim.quick) {
                selectedBudget = level
            }
        } label: {
            HStack(spacing: OuestTheme.Spacing.md) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? OuestTheme.Colors.brand : OuestTheme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.body.weight(.medium))
                        .foregroundStyle(OuestTheme.Colors.textPrimary)
                    Text(level.subtitle)
                        .font(OuestTheme.Typography.micro)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(OuestTheme.Spacing.md)
            .background(
                isSelected ? OuestTheme.Colors.brandLight : OuestTheme.Colors.surfaceSecondary.opacity(0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                    .strokeBorder(
                        isSelected ? OuestTheme.Colors.brand.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        OuestButton(
            title: existingDaysCount > 0 ? "Replace with AI itinerary" : "Generate Itinerary",
            isLoading: viewModel.isGeneratingAI
        ) {
            Task {
                let preferences = TripPreferences(
                    vibes: selectedVibes.map(\.rawValue),
                    budgetLevel: selectedBudget.rawValue
                )
                let success = await viewModel.generateAIItinerary(preferences: preferences)
                if success {
                    dismiss()
                }
            }
        }
        .disabled(!canGenerate)
        .opacity(canGenerate ? 1 : 0.5)
        .fadeSlideIn(isVisible: appeared, delay: 0.2)
    }

    /// Approximate count of existing days — used to warn that generation replaces content.
    private var existingDaysCount: Int {
        viewModel.days.count
    }

    private var fineprint: some View {
        VStack(spacing: OuestTheme.Spacing.xs) {
            if existingDaysCount > 0 {
                Label(
                    "This will replace your current \(existingDaysCount)-day itinerary.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(OuestTheme.Typography.caption)
                .foregroundStyle(OuestTheme.Colors.warning)
            }
            Text("Powered by Claude. Generated suggestions may include inaccuracies — verify times and locations before committing.")
                .font(OuestTheme.Typography.micro)
                .foregroundStyle(OuestTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OuestTheme.Spacing.lg)
        }
        .fadeSlideIn(isVisible: appeared, delay: 0.25)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        AIProgressView(
            icon: "sparkles",
            phases: [
                "Reading your trip details…",
                "Searching for hidden gems in \(trip.destination)…",
                "Drafting your day-by-day plan…",
                "Mapping locations and timing…",
                "Adding final touches…",
            ],
            estimatedDuration: 28
        )
    }

    // MARK: - Bindings

    private var aiErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.aiError != nil },
            set: { if !$0 { viewModel.aiError = nil } }
        )
    }

    // MARK: - Profile Pre-fill

    /// Populate the vibe chips and budget level from the user's onboarding interests
    /// the first time the sheet appears. Users can still toggle freely.
    private func prefillFromProfileIfNeeded() {
        guard !prefilledFromProfile else { return }
        let interests = authViewModel.currentUser?.travelInterests ?? []
        let derivedVibes = interests.compactMap(TripVibe.fromTravelInterest)
        if !derivedVibes.isEmpty {
            selectedVibes = Set(derivedVibes)
        }
        selectedBudget = TripBudgetLevel.fromTravelInterests(interests)
        prefilledFromProfile = true
    }
}

#Preview {
    let trip = Trip(
        id: UUID(), createdBy: UUID(),
        title: "Barcelona", destination: "Barcelona, Spain",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * 86400),
        status: .planning, isPublic: false,
        createdAt: Date(), updatedAt: Date()
    )
    return AIGenerateView(
        trip: trip,
        viewModel: ItineraryViewModel(trip: trip)
    )
    .environment(AuthViewModel())
}
