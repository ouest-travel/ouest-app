import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Animation Modifiers
//
// Design brief §Motion adopts **policy 2b — fade, never move**.
//
// - Every named entrance drops translation / scale / rotation to zero when
//   the user has Reduce Motion on. A 0.2s opacity fade replaces the spring.
//   Instant appearance reads as a glitch, so we keep an animation — just
//   without any actual motion.
// - `pulse` and `shimmer` use `.repeatForever`, which a fade does not stop.
//   They need an explicit off switch when Reduce Motion is on. That check
//   lives inside each ViewModifier so no call site has to remember.
// - `stagger()` on `Anim` still applies under Reduce Motion — a delayed
//   fade involves no motion.
//
// Public surface (the brief's target is five):
//   appear(isVisible:index:)  — canonical entrance. New sites should use it.
//   pulse(isActive:)          — attention throb.
//   shimmer()                 — loading placeholder sweep.
//   likeBurst(trigger:)       — celebration.
//   shake(_:)                 — error shake.
//
// The four legacy entrance names (fadeSlideIn / bouncyAppear / warmReveal /
// cardEntrance) are retained as thin wrappers that call `appear` — the
// visual differences between them (scale on warmReveal, rotation on
// cardEntrance, etc.) never justified four APIs. Sweeping all ~130 call
// sites to `appear` is a mechanical follow-up.
//
// pulseEffect / shimmerEffect / shakeOnError are likewise kept as aliases
// for the renamed pulse / shimmer / shake.

extension View {

    // MARK: Canonical entrance

    /// The one entrance modifier. Fade + 16pt rise on appear, staggered by
    /// `index`. Under Reduce Motion the rise drops to zero and the spring
    /// becomes a 0.2s ease-in-out — no motion, but still an animation.
    func appear(_ isVisible: Bool, index: Int = 0) -> some View {
        modifier(AppearModifier(isVisible: isVisible, index: index))
    }

    // MARK: Attention

    /// Subtle scale + opacity throb. Static under Reduce Motion.
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }

    // MARK: Loading

    /// Shimmer sweep across the content. Static under Reduce Motion.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    // MARK: Celebration

    /// Particle burst overlay. The burst itself is a one-shot animation;
    /// under Reduce Motion the particles fade in place instead of flying out.
    func likeBurst(trigger: Bool) -> some View {
        modifier(LikeBurstModifier(trigger: trigger))
    }

    // MARK: Error

    /// Horizontal shake on error. Under Reduce Motion the shake is skipped
    /// entirely; callers should surface the error message textually — which
    /// they already do — so nothing is lost.
    func shake(_ trigger: Bool) -> some View {
        modifier(ShakeModifier(shaking: trigger))
    }

    // MARK: Zoom transition (iOS 18+)

    /// Marks this view as the source of an `.navigationTransition(.zoom:in:)`.
    /// The tapped card grows into the destination hero on iOS 18. Under
    /// iOS 17 (or when `namespace` is nil, e.g. in previews), this is a
    /// no-op and the stock push transition applies.
    @ViewBuilder
    func zoomSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Applies `.navigationTransition(.zoom:in:)` on the destination view.
    /// No-op on iOS 17 or when a namespace is not provided. The system
    /// automatically cross-fades instead of zooming when Reduce Motion is
    /// on, so no manual gating is required here.
    @ViewBuilder
    func zoomDestination<ID: Hashable>(id: ID?, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let id, let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }

    // MARK: Press feedback (unchanged — press isn't a "motion" concern)

    /// Press/tap scale feedback — shrinks slightly when pressed
    func pressEffect(scale: CGFloat = 0.97) -> some View {
        modifier(PressEffectModifier(pressedScale: scale))
    }

    // MARK: - Legacy aliases
    //
    // These forward to the canonical modifiers so the ~130 existing call
    // sites keep working while the sweep happens gradually. Same behaviour;
    // same Reduce Motion policy. New code should not use these names.

    func fadeSlideIn(isVisible: Bool, delay: Double = 0) -> some View {
        appear(isVisible, index: staggerIndex(from: delay))
    }

    func bouncyAppear(isVisible: Bool, delay: Double = 0) -> some View {
        appear(isVisible, index: staggerIndex(from: delay))
    }

    func warmReveal(isVisible: Bool, delay: Double = 0) -> some View {
        appear(isVisible, index: staggerIndex(from: delay))
    }

    func cardEntrance(isVisible: Bool, delay: Double = 0) -> some View {
        appear(isVisible, index: staggerIndex(from: delay))
    }

    func pulseEffect(isActive: Bool = true) -> some View {
        pulse(isActive: isActive)
    }

    func shimmerEffect() -> some View {
        shimmer()
    }

    func shakeOnError(_ trigger: Bool) -> some View {
        shake(trigger)
    }
}

// Legacy delay params map to the stagger index the base spring uses (0.06s
// per step). Round rather than floor so 0.05 rounds to index 1 instead of 0.
private func staggerIndex(from delay: Double) -> Int {
    max(0, Int((delay / 0.06).rounded()))
}

// MARK: - Appear (canonical entrance)

private struct AppearModifier: ViewModifier {
    let isVisible: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // Policy 2b: no offset when Reduce Motion is on. The value is
        // resolved into the initial state so the offset is never applied,
        // not just animated to zero.
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: (isVisible || reduceMotion) ? 0 : 16)
            .animation(animation, value: isVisible)
    }

    private var animation: Animation {
        let delay = Double(index) * 0.06
        if reduceMotion {
            return .easeInOut(duration: 0.2).delay(delay)
        }
        return .spring(duration: 0.45, bounce: 0.12).delay(delay)
    }
}

// MARK: - Shimmer Modifier

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay {
                // A .repeatForever animation is not stopped by a fade —
                // Reduce Motion means "no motion", so we drop the overlay
                // entirely and render the static content.
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                // Dark uses 12% white per the design brief;
                                // 40% was overpowering on the near-black
                                // page and made skeletons visibly strobe.
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.4),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * (geo.size.width * 1.6) - geo.size.width * 0.3)
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

// MARK: - Press Effect Modifier (for non-button views)

private struct PressEffectModifier: ViewModifier {
    let pressedScale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .brightness(isPressed ? 0.03 : 0)
            .animation(OuestTheme.Anim.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Scaled Button Style (for NavigationLink / Button — works with tap gestures)

/// Use this instead of `.pressEffect()` on NavigationLinks and Buttons
/// to avoid DragGesture stealing the tap.
struct ScaledButtonStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(OuestTheme.Anim.quick, value: configuration.isPressed)
    }
}

// MARK: - Shake Modifier

private struct ShakeModifier: ViewModifier {
    let shaking: Bool
    @State private var shakeOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: shaking) { _, isShaking in
                guard isShaking, !reduceMotion else { return }
                Task { @MainActor in
                    withAnimation(.spring(duration: 0.08, bounce: 0)) {
                        shakeOffset = -8
                    }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.spring(duration: 0.08, bounce: 0)) {
                        shakeOffset = 8
                    }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.spring(duration: 0.08, bounce: 0)) {
                        shakeOffset = -4
                    }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.spring(duration: 0.12, bounce: 0.2)) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            // Under Reduce Motion, freeze at scale 1 / opacity 1 — no throb.
            .scaleEffect(shouldAnimate && isPulsing ? 1.08 : 1.0)
            .opacity(shouldAnimate && isPulsing ? 0.85 : 1.0)
            .onAppear {
                guard shouldAnimate else { return }
                startPulsing()
            }
            .onChange(of: isActive) { _, active in
                if active, shouldAnimate {
                    startPulsing()
                } else {
                    withAnimation { isPulsing = false }
                }
            }
    }

    private var shouldAnimate: Bool { isActive && !reduceMotion }

    private func startPulsing() {
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}

// MARK: - Skeleton Placeholder View

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = OuestTheme.Radius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(OuestTheme.Colors.surfaceTertiary)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Trip Card (for loading state)

struct SkeletonTripCard: View {
    var body: some View {
        HStack(spacing: 14) {
            SkeletonView(height: 80)
                .frame(width: 80)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 140, height: 16)
                SkeletonView(width: 100, height: 12)
                SkeletonView(width: 80, height: 12)
            }
            Spacer()
        }
        .padding(12)
        .background(OuestTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
        .ouestElevation(.md)
    }
}

// MARK: - Like Burst Modifier

private struct LikeBurstModifier: ViewModifier {
    let trigger: Bool
    @State private var particles: [BurstParticle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    ForEach(particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .scaleEffect(particle.isActive ? 0 : 1)
                            .opacity(particle.isActive ? 0 : 1)
                            .offset(
                                // Under Reduce Motion, particles fade in place
                                // instead of flying outward.
                                x: center.x + (particle.isActive && !reduceMotion ? particle.endX : 0) - particle.size / 2,
                                y: center.y + (particle.isActive && !reduceMotion ? particle.endY : 0) - particle.size / 2
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, isActive in
                guard isActive else { return }
                burst()
            }
    }

    private func burst() {
        let count = Int.random(in: 6...8)
        var newParticles: [BurstParticle] = []
        let colors: [Color] = [
            Color(hex: 0x2563EB),
            Color(hex: 0x38BDF8),
            Color(hex: 0x3B82F6),
            Color(hex: 0x60A5FA),
        ]

        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double.random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 20...40)
            newParticles.append(BurstParticle(
                color: colors[i % colors.count],
                size: CGFloat.random(in: 4...8),
                endX: cos(angle) * distance,
                endY: sin(angle) * distance
            ))
        }

        particles = newParticles

        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            for i in particles.indices {
                particles[i].isActive = true
            }
        }

        // Clean up after animation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            particles = []
        }
    }
}

private struct BurstParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    var isActive = false
}

// MARK: - Haptic feedback helpers

enum HapticFeedback {
    @MainActor
    static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor
    static func medium() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    @MainActor
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    @MainActor
    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    @MainActor
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
