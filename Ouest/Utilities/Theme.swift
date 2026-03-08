import SwiftUI

// MARK: - Ouest Design System

enum OuestTheme {

    // MARK: - Colors

    enum Colors {
        // Brand
        static let brand = Color(hex: 0x2563EB)            // Royal Blue
        static let brandLight = Color(hex: 0x2563EB).opacity(0.12)
        static let brandCyan = Color(hex: 0x38BDF8)         // Sky Blue (accent)
        static let brandBlue = Color(hex: 0x1E40AF)         // Blue 800 (depth)
        static let brandGradient = LinearGradient(
            colors: [Color(hex: 0x2563EB), Color(hex: 0x38BDF8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Surfaces (adaptive light/dark)
        static let surface = Color("Surface")
        static let surfaceSecondary = Color("SurfaceSecondary")
        static let surfaceTertiary = Color("SurfaceTertiary")

        // Text
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textInverse = Color.white

        // Semantic
        static let success = Color(hex: 0x10B981)          // Emerald
        static let warning = Color(hex: 0xF59E0B)          // Amber
        static let error = Color(hex: 0xEF4444)            // Red 500

        // Trip Status
        static let planning = Color(hex: 0xF59E0B)         // Amber
        static let active = Color(hex: 0x10B981)           // Emerald
        static let completed = Color(hex: 0x64748B)        // Slate 500

        // Deep Navy (dark mode base)
        static let deepNavy = Color(hex: 0x0C1222)

        // Gradient palettes for trip cards (destination-based)
        static let tripGradients: [[Color]] = [
            [Color(hex: 0x2563EB), Color(hex: 0x38BDF8)],  // Royal → Sky
            [Color(hex: 0x38BDF8), Color(hex: 0x1E40AF)],  // Sky → Blue800
            [Color(hex: 0x10B981), Color(hex: 0x14B8A6)],  // Emerald → Teal
            [Color(hex: 0xF59E0B), Color(hex: 0xF97316)],  // Amber → Orange
            [Color(hex: 0x4F46E5), Color(hex: 0x2563EB)],  // Indigo → Blue
            [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)],  // Blue → Cyan
            [Color(hex: 0x64748B), Color(hex: 0x0C1222)],  // Slate → Navy
            [Color(hex: 0x14B8A6), Color(hex: 0x10B981)],  // Teal → Emerald
        ]
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

    // MARK: - Shadows (blue-tinted)

    enum Shadow {
        static let sm = ShadowStyle(color: Color(hex: 0x2563EB).opacity(0.04), radius: 4, y: 1)
        static let md = ShadowStyle(color: Color(hex: 0x2563EB).opacity(0.08), radius: 12, y: 4)
        static let lg = ShadowStyle(color: Color(hex: 0x2563EB).opacity(0.12), radius: 20, y: 6)
        static let pressed = ShadowStyle(color: Color(hex: 0x2563EB).opacity(0.04), radius: 2, y: 1)
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
        // Fraunces headings — using UIFont for reliable variable-font weight rendering
        static let heroTitle: Font = fraunces(size: 36, weight: .bold)
        static let screenTitle: Font = fraunces(size: 28, weight: .bold)
        static let sectionTitle: Font = fraunces(size: 18, weight: .semibold)

        // System body text
        static let cardTitle: Font = .system(size: 17, weight: .bold)
        static let body: Font = .system(size: 15)
        static let caption: Font = .system(size: 13)
        static let micro: Font = .system(size: 11, weight: .semibold)

        /// Create a Fraunces font with precise weight via UIFont descriptor
        private static func fraunces(size: CGFloat, weight: UIFont.Weight) -> Font {
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: "Fraunces",
            ]).addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight],
            ])
            return Font(UIFont(descriptor: descriptor, size: size))
        }
    }
}

// MARK: - Shadow Style helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

// MARK: - View modifier for applying shadow style

extension View {
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}

// MARK: - Color hex initializer

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
