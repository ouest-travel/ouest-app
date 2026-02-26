import SwiftUI

// MARK: - Animation Modifiers

extension View {

    /// Shimmer loading effect — animated gradient sweep for skeleton placeholders
    func shimmerEffect() -> some View {
        modifier(ShimmerModifier())
    }

    /// Press/tap scale feedback — shrinks slightly when pressed
    func pressEffect(scale: CGFloat = 0.97) -> some View {
        modifier(PressEffectModifier(pressedScale: scale))
    }

    /// Fade + slide in from bottom with optional delay (for staggered list appearance)
    func fadeSlideIn(isVisible: Bool, delay: Double = 0) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(OuestTheme.Anim.smooth.delay(delay), value: isVisible)
    }

    /// Shake animation on error (horizontal oscillation)
    func shakeOnError(_ trigger: Bool) -> some View {
        modifier(ShakeModifier(shaking: trigger))
    }

    /// Pulse animation (subtle scale throb) — great for badges, live indicators
    func pulseEffect(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }

    /// Bouncy appear animation — scales from 0 to 1 with spring
    func bouncyAppear(isVisible: Bool, delay: Double = 0) -> some View {
        self
            .scaleEffect(isVisible ? 1 : 0.5)
            .opacity(isVisible ? 1 : 0)
            .animation(OuestTheme.Anim.bouncy.delay(delay), value: isVisible)
    }
}

// MARK: - Shimmer Modifier

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * (geo.size.width * 1.6) - geo.size.width * 0.3)
                }
                .clipped()
            }
            .onAppear {
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
            .animation(OuestTheme.Anim.quick, value: configuration.isPressed)
    }
}

// MARK: - Shake Modifier

private struct ShakeModifier: ViewModifier {
    let shaking: Bool
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: shaking) { _, isShaking in
                guard isShaking else { return }
                withAnimation(.spring(duration: 0.08, bounce: 0)) {
                    shakeOffset = -8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(duration: 0.08, bounce: 0)) {
                        shakeOffset = 8
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(duration: 0.08, bounce: 0)) {
                        shakeOffset = -4
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
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

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive ? 1.08 : 1.0)
            .opacity(isPulsing && isActive ? 0.85 : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                    ) {
                        isPulsing = true
                    }
                } else {
                    withAnimation { isPulsing = false }
                }
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
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmerEffect()
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
        .shadow(OuestTheme.Shadow.md)
    }
}

// MARK: - Haptic feedback helpers

enum HapticFeedback {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
