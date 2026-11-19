import SwiftUI

// MARK: - Style

/// The two decorative backdrops a user can pick for their profile card.
/// Persisted per device via `@AppStorage(ProfileHeaderStyle.storageKey)`.
enum ProfileHeaderStyle: String, CaseIterable, Identifiable {
    case mesh
    case grain

    static let storageKey = "profileHeaderStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mesh: "Mesh"
        case .grain: "Grain"
        }
    }

    /// Noise amplitude passed to the shader. Mesh is clean; grain adds a
    /// static film-like texture.
    var grainAmount: Float {
        switch self {
        case .mesh: 0
        case .grain: 0.22
        }
    }
}

// MARK: - Motion policy

/// When the header may animate. Pulled out as a pure function so the
/// accessibility and battery rules are testable without a view.
///
/// Design brief §Motion: "fade, never move". A continuously redrawing
/// shader is motion, so any of these freezes it at t = 0 (a still mesh
/// gradient, not a flat colour):
/// - Reduce Motion: the user asked for no movement.
/// - Dim Flashing Lights: slow colour drift is not flashing, but users who
///   set this are the most sensitive group, so err on the side of still.
/// - Low Power Mode: a 30fps redraw is a standing battery cost.
/// - Not active: no point drawing under a sheet or in the background.
enum MeshHeaderMotionPolicy {
    static func shouldAnimate(
        reduceMotion: Bool,
        dimFlashingLights: Bool,
        lowPowerMode: Bool,
        isActive: Bool
    ) -> Bool {
        !reduceMotion && !dimFlashingLights && !lowPowerMode && isActive
    }
}

// MARK: - View

/// Animated mesh / grain gradient for decorative hero areas. Built on the
/// `decorGradient` and `inkGradient` tokens so it adapts to dark mode.
/// Decorative only: hidden from VoiceOver. Size it with `.frame(height:)`.
struct MeshGradientHeader: View {
    var style: ProfileHeaderStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights
    @Environment(\.scenePhase) private var scenePhase
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var start = Date()

    private var isAnimating: Bool {
        MeshHeaderMotionPolicy.shouldAnimate(
            reduceMotion: reduceMotion,
            dimFlashingLights: dimFlashingLights,
            lowPowerMode: lowPowerMode,
            isActive: scenePhase == .active
        )
    }

    var body: some View {
        GeometryReader { geo in
            // 30fps is plenty for a drift this slow and halves the GPU cost
            // versus the display's native rate.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)) { context in
                let time: Float = isAnimating
                    ? Float(context.date.timeIntervalSince(start))
                    : 0
                Rectangle()
                    .fill(OuestTheme.Colors.brandFill)
                    .colorEffect(
                        ShaderLibrary.ouestMeshGradient(
                            .float2(geo.size),
                            .float(time),
                            .color(Color("DecorGradientStart")),
                            .color(Color("DecorGradientEnd")),
                            .color(Color("InkGradientEnd")),
                            .color(Color("DecorGradientEnd")),
                            .float(style.grainAmount)
                        )
                    )
            }
        }
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

// MARK: - Previews

#Preview("Mesh") {
    MeshGradientHeader(style: .mesh)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl, style: .continuous))
        .padding()
}

#Preview("Grain") {
    MeshGradientHeader(style: .grain)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl, style: .continuous))
        .padding()
}

#Preview("Mesh — dark") {
    MeshGradientHeader(style: .mesh)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.xl, style: .continuous))
        .padding()
        .preferredColorScheme(.dark)
}
