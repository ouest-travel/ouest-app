import SwiftUI

// MARK: - Ouest Design System

enum OuestTheme {

    // MARK: - Colors

    enum Colors {
        // Brand
        static let brand = Color.teal
        static let brandLight = Color.teal.opacity(0.15)
        static let brandGradient = LinearGradient(
            colors: [.teal, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Surfaces
        static let surface = Color(.systemBackground)
        static let surfaceSecondary = Color(.systemGray6)
        static let surfaceTertiary = Color(.systemGray5)

        // Text
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textInverse = Color(.systemBackground)

        // Semantic
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red

        // Trip Status
        static let planning = Color.blue
        static let active = Color.green
        static let completed = Color(.systemGray)

        // Gradient palettes for trip cards (destination-based)
        static let tripGradients: [[Color]] = [
            [.blue, .purple],
            [.teal, .blue],
            [.orange, .pink],
            [.green, .teal],
            [.indigo, .blue],
            [.pink, .orange],
            [.purple, .indigo],
            [.mint, .green],
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
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 999   // Capsule
    }

    // MARK: - Shadows

    enum Shadow {
        static let sm = ShadowStyle(color: .black.opacity(0.04), radius: 4, y: 1)
        static let md = ShadowStyle(color: .black.opacity(0.06), radius: 8, y: 2)
        static let lg = ShadowStyle(color: .black.opacity(0.1), radius: 16, y: 4)
        static let pressed = ShadowStyle(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - Animation

    enum Anim {
        static let quick = SwiftUI.Animation.spring(duration: 0.25, bounce: 0.15)
        static let smooth = SwiftUI.Animation.spring(duration: 0.4, bounce: 0.12)
        static let gentle = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.1)
        static let bouncy = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.3)

        /// Staggered delay for list items
        static func stagger(_ index: Int, base: Double = 0.05) -> SwiftUI.Animation {
            .spring(duration: 0.45, bounce: 0.12).delay(Double(index) * base)
        }
    }

    // MARK: - Typography helpers

    enum Typography {
        static let heroTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
        static let screenTitle: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle: Font = .system(size: 17, weight: .semibold)
        static let cardTitle: Font = .system(size: 17, weight: .semibold)
        static let body: Font = .system(size: 15)
        static let caption: Font = .system(size: 13)
        static let micro: Font = .system(size: 11, weight: .medium)
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
