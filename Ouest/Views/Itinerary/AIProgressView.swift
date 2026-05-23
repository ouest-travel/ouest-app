import SwiftUI

/// Shared progress view shown while the AI itinerary Edge Function is running.
///
/// The Edge Function is a single synchronous call (10–40s of Claude latency),
/// so there's no real progress to surface. Instead we drive a perceived-progress
/// bar that fills to ~95% over an estimated duration and rotate descriptive
/// phase labels — enough to tell the user the app is still working without
/// lying about how close we are to done. When the parent flips its loading
/// state off, the view dismisses regardless of where the bar landed.
struct AIProgressView: View {
    /// SF Symbol shown inside the brand badge (e.g. "sparkles", "wand.and.stars").
    let icon: String

    /// Status messages cycled through in order — each gets an equal slice of the
    /// estimated window. Keep them short and verb-led ("Drafting your plan…").
    let phases: [String]

    /// Rough wall-clock expectation in seconds. Bar fills 0 → 0.95 over this.
    /// Hold at 0.95 until the parent dismisses.
    let estimatedDuration: Double

    @State private var elapsed: Double = 0

    // 0.5s tick gives a smooth bar without hammering the run loop.
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var progress: Double {
        min(elapsed / estimatedDuration, 0.95)
    }

    /// Pick a phase by mapping elapsed time onto equal slices of phases.count.
    private var currentPhase: String {
        guard !phases.isEmpty else { return "" }
        let slice = max(estimatedDuration / Double(phases.count), 1)
        let index = min(Int(elapsed / slice), phases.count - 1)
        return phases[index]
    }

    var body: some View {
        VStack(spacing: OuestTheme.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(OuestTheme.Colors.brandLight)
                    .frame(width: 120, height: 120)
                    .shimmerEffect()

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brandGradient)
                    .symbolEffect(.pulse, options: .repeating)
            }

            Text(currentPhase)
                .font(OuestTheme.Typography.screenTitle)
                .foregroundStyle(OuestTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .contentTransition(.opacity)
                .animation(OuestTheme.Anim.smooth, value: currentPhase)
                .frame(minHeight: 60) // Avoid layout jump when phase length changes

            VStack(spacing: OuestTheme.Spacing.sm) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(OuestTheme.Colors.brand)
                    .frame(maxWidth: 220)
                    .animation(.linear(duration: 0.5), value: progress)

                Text("This usually takes 20–40 seconds")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(OuestTheme.Spacing.lg)
        .onReceive(timer) { _ in
            elapsed += 0.5
        }
    }
}

#Preview {
    AIProgressView(
        icon: "sparkles",
        phases: [
            "Reading your trip details…",
            "Searching for hidden gems in Barcelona…",
            "Drafting your day-by-day plan…",
            "Mapping locations and timing…",
            "Adding final touches…",
        ],
        estimatedDuration: 28
    )
}
