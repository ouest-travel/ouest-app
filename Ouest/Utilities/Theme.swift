import SwiftUI

// MARK: - Ouest Design System

/// Token layer. Every colour resolves through `Assets.xcassets` so light and
/// dark appearances stay in one place. `Color(hex:)` should live only inside
/// colorset definitions — never in a view.
enum OuestTheme {

    // MARK: - Colors

    enum Colors {
        // Surfaces
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let surfaceRaised = Color("SurfaceRaised")
        static let fill = Color("Fill")
        static let border = Color("Border")

        // Backwards-compat aliases — sweep in Phase 2. Both new call sites
        // and old ones land on the correct colorset in the meantime.
        static let surfaceSecondary = Color("Fill")
        static let surfaceTertiary = Color("Fill")

        // Text
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        static let textInverse = Color.white

        // Brand
        static let brandFill = Color("BrandFill")            // button fills, ring
        static let brandInk = Color("BrandInk")              // brand-coloured text
        static let brandFillPressed = Color("BrandFillPressed")
        static let brandOutline = Color("BrandOutline")

        /// Alias — anywhere old code writes `Colors.brand`. Same #2563EB in
        /// both appearances, matches the previous literal value.
        static let brand = Color("BrandFill")

        /// Faint tint used behind icons or as .accent overlay. #2563EB @ 12%.
        static let brandLight = Color("BrandFill").opacity(0.12)

        // Gradients — never assign a colour directly to a gradient stop; use
        // one of these two.
        static let decorGradient = LinearGradient(
            colors: [Color("DecorGradientStart"), Color("DecorGradientEnd")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let inkGradient = LinearGradient(
            colors: [Color("InkGradientStart"), Color("InkGradientEnd")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Semantic
        static let error = Color("Error")
        static let errorInk = Color("ErrorInk")
        static let errorTint = Color("ErrorTint")
        static let successFill = Color("SuccessFill")
        static let warningInk = Color("WarningInk")

        // Backwards-compat aliases — sweep in Phase 2.
        static let success = Color("SuccessFill")
        static let warning = Color("WarningInk")

        // Deep navy — kept for the two places that use it as a literal
        // (LoginView gradient, splash). Not a role.
        static let deepNavy = Color(hex: 0x0C1222)

        // Destination gradients — 8 pairs, each already carrying a dark
        // variant one step deeper. Access via TripGradient(index) below.
        static let tripGradients: [[Color]] = (0..<8).map { i in
            [Color("TripGradient\(i)Start"), Color("TripGradient\(i)End")]
        }
    }

    // MARK: - Status styles

    /// Trip status is a pair, not a single colour. Tint carries the fill
    /// and ink carries the text on top of that fill — bundling them stops
    /// anyone picking one without the other.
    struct StatusStyle: Sendable {
        let tint: Color
        let ink: Color

        static let planning = StatusStyle(
            tint: Color("StatusPlanningTint"),
            ink: Color("StatusPlanningInk")
        )
        static let active = StatusStyle(
            tint: Color("StatusActiveTint"),
            ink: Color("StatusActiveInk")
        )
        static let completed = StatusStyle(
            tint: Color("StatusCompletedTint"),
            ink: Color("StatusCompletedInk")
        )
    }

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14     // refined from 12
        static let lg: CGFloat = 20     // refined from 16
        static let xl: CGFloat = 24     // refined from 20
        static let full: CGFloat = 999  // Capsule
    }

    // MARK: - Layout

    /// Semantic layout intents. Sits above `Spacing` — `Spacing.lg` is a
    /// raw 16pt, `Layout.pageGutter` is "the horizontal breathing room
    /// around a screen's content." Same number, different meaning; the
    /// name makes site-level choices reviewable.
    enum Layout {
        /// Horizontal breathing room at the edges of a screen's content.
        static let pageGutter: CGFloat = 16
        /// Padding inside a card or panel.
        static let cardPadding: CGFloat = 16
        /// Vertical gap between cards in the same section.
        static let stackGap: CGFloat = 12
        /// Vertical gap between sections on the same screen.
        static let sectionGap: CGFloat = 28
        /// Bottom padding every tab's scroll view needs so the last row
        /// doesn't run under the floating tab bar + AI-run bubble.
        static let tabBarInset: CGFloat = 96
        /// Height every control (button, text field) already agrees on.
        static let controlHeight: CGFloat = 50
    }

    // MARK: - Icons

    /// Four Dynamic-Type-aware icon sizes. Prefer these over
    /// `.font(.system(size:))`, which ignores the user's text-size setting
    /// and is why icons stayed frozen while everything else scaled.
    enum Icon {
        /// Beside body text — inline glyph or badge.
        static let inline: Font = .body
        /// Tab-bar and toolbar controls. 20pt at default size.
        static let control: Font = .title3
        /// Section marks, feature callouts. 34pt at default size.
        static let feature: Font = .largeTitle
        /// Empty-state art only. Capped on purpose — see brief §Icons.
        static let hero: CGFloat = 56
    }

    // MARK: - Elevation

    /// Appearance-aware elevation. A blue shadow at 4–12% alpha is invisible
    /// on `#0C1222`, so dark-mode cards had no separation from the page.
    /// Light gets a neutral shadow; dark gets a 1pt border in `Border`.
    enum Elevation {
        case sm, md, lg, pressed
    }

    // MARK: - Animation

    enum Anim {
        static let quick = SwiftUI.Animation.spring(duration: 0.25, bounce: 0.15)
        static let smooth = SwiftUI.Animation.spring(duration: 0.4, bounce: 0.12)
        static let gentle = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.1)
        static let bouncy = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.3)

        /// Staggered delay for list items
        static func stagger(_ index: Int, base: Double = 0.06) -> SwiftUI.Animation {
            .spring(duration: 0.45, bounce: 0.12).delay(Double(index) * base)
        }
    }

    // MARK: - Typography helpers

    enum Typography {
        // Fraunces headings — using UIFont for reliable variable-font weight rendering,
        // scaled via UIFontMetrics so Dynamic Type keeps working.
        static let heroTitle: Font = fraunces(size: 36, weight: .bold, textStyle: .largeTitle)
        static let screenTitle: Font = fraunces(size: 28, weight: .bold, textStyle: .title1)
        static let sectionTitle: Font = fraunces(size: 18, weight: .semibold, textStyle: .title3)

        // System body text — mapped to text styles so it scales with the user's
        // Larger Text setting. Default sizes match the previous hardcoded values.
        static let cardTitle: Font = .system(.body, weight: .bold)     // 17pt at default
        static let body: Font = .system(.subheadline)                  // 15pt at default
        static let caption: Font = .system(.footnote)                  // 13pt at default
        static let micro: Font = .system(.caption2, weight: .semibold) // 11pt at default

        /// Create a Fraunces font with precise weight via UIFont descriptor,
        /// then scale it against a text style so Dynamic Type takes effect.
        private static func fraunces(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> Font {
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: "Fraunces",
            ]).addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight],
            ])
            let base = UIFont(descriptor: descriptor, size: size)
            let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
            return Font(scaled)
        }
    }
}

// MARK: - Elevation view modifier

/// Apply `.ouestElevation(.md)` in place of the old `.shadow(OuestTheme.Shadow.md)`.
/// Light appearance gets a neutral shadow; dark gets a hairline `Border` outline
/// instead, since a low-alpha shadow disappears on the dark page.
///
/// The `cornerRadius` parameter matches the border to whatever shape the card
/// already clips itself to. Defaults to `Radius.lg` (the standard card radius).
private struct OuestElevation: ViewModifier {
    let level: OuestTheme.Elevation
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            // Dark: no shadow. Separate cards with a 1pt border in `Border`.
            content.overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(OuestTheme.Colors.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
        } else {
            switch level {
            case .sm:
                content.shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 1)
            case .md:
                content.shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
            case .lg:
                content.shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 6)
            case .pressed:
                content.shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
    }
}

extension View {
    /// Apply an appearance-aware elevation. Prefer this over a raw `.shadow`.
    /// Pass `cornerRadius` to match your card's clip shape so the dark-mode
    /// hairline border sits on the same silhouette; defaults to `Radius.lg`.
    func ouestElevation(_ level: OuestTheme.Elevation, cornerRadius: CGFloat = OuestTheme.Radius.lg) -> some View {
        modifier(OuestElevation(level: level, cornerRadius: cornerRadius))
    }
}

// MARK: - Color hex initializer (kept for the two literal call sites and
// for the transition; new code should use Assets.xcassets colorsets).

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
