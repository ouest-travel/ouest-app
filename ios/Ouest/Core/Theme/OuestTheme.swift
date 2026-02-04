import SwiftUI

// MARK: - Ouest Design System
/// Partiful-inspired theme with Ouest brand colors
/// Supports Dynamic Type and accessibility

enum OuestTheme {

    // MARK: - Brand Colors (from Ouest web app)

    enum Brand {
        static let blue = Color(hex: "4F8FFF")      // Primary blue
        static let pink = Color(hex: "C77DFF")      // Vibrant pink
        static let coral = Color(hex: "FF8B94")     // Soft coral
        static let indigo = Color(hex: "6366F1")    // Deep indigo
    }

    // MARK: - Semantic Colors

    enum Colors {
        // Primary actions
        static let primary = Brand.blue
        static let primaryLight = Color(hex: "7AABFF")
        static let primaryDark = Color(hex: "3A7AE6")

        // Legacy aliases for backwards compatibility
        static let pink = Brand.pink
        static let coral = Brand.coral
        static let indigo = Brand.indigo

        // Secondary/Accent
        static let accent = Brand.pink
        static let accentLight = Color(hex: "D9A3FF")

        // Semantic
        static let success = Color(hex: "34C759")    // Apple green
        static let warning = Color(hex: "FF9F0A")    // Apple orange
        static let error = Color(hex: "FF3B30")      // Apple red

        // Text - ensuring WCAG AA contrast (4.5:1 minimum)
        static let text = Color(hex: "1A1A2E")            // Near black, 15:1 contrast
        static let textPrimary = Color(hex: "1A1A2E")
        static let textSecondary = Color(hex: "636366")   // System gray, 5.5:1 contrast
        static let textTertiary = Color(hex: "8E8E93")    // Light gray, 3.5:1 (large text)
        static let textInverse = Color.white

        // Backgrounds
        static let background = Color(hex: "FAFBFC")           // Soft off-white
        static let backgroundSecondary = Color(hex: "F2F2F7")  // System grouped background
        static let card = Color.white
        static let cardBackground = Color.white
        static let cardElevated = Color.white

        // Input
        static let inputBackground = Color(hex: "F5F5F7")
        static let inputBorder = Color(hex: "E5E5EA")
        static let borderFocused = Brand.blue

        // Borders & Dividers
        static let border = Color(hex: "E5E5EA")
        static let divider = Color(hex: "C6C6C8").opacity(0.5)

        // Category colors for expenses
        enum Category {
            static let food = Color(hex: "FF9500")        // Orange
            static let transport = Brand.blue             // Blue
            static let stay = Color(hex: "AF52DE")        // Purple
            static let activities = Color(hex: "30D158")  // Green
            static let other = Color(hex: "8E8E93")       // Gray
        }

        // Dark mode variants
        enum Dark {
            static let text = Color(hex: "FFFFFF")
            static let textPrimary = Color(hex: "FFFFFF")
            static let textSecondary = Color(hex: "EBEBF5").opacity(0.6)
            static let textTertiary = Color(hex: "EBEBF5").opacity(0.3)
            static let background = Color(hex: "000000")
            static let backgroundSecondary = Color(hex: "1C1C1E")
            static let card = Color(hex: "1C1C1E")
            static let cardBackground = Color(hex: "1C1C1E")
            static let cardElevated = Color(hex: "2C2C2E")
            static let inputBackground = Color(hex: "2C2C2E")
            static let inputBorder = Color(hex: "3A3A3C")
            static let border = Color(hex: "38383A")
            static let divider = Color(hex: "545458").opacity(0.6)
        }
    }

    // MARK: - Gradients (Partiful-inspired, using Ouest colors)

    enum Gradients {
        /// Main brand gradient - used for CTAs and hero elements
        static let primary = LinearGradient(
            colors: [Brand.blue, Brand.indigo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Vibrant multi-color gradient - used for special moments
        static let ouest = LinearGradient(
            colors: [Brand.blue, Brand.pink, Brand.coral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Full spectrum gradient
        static let spectrum = LinearGradient(
            colors: [Brand.blue, Brand.pink, Brand.coral, Brand.indigo],
            startPoint: .leading,
            endPoint: .trailing
        )

        /// Soft gradient for cards
        static let card = LinearGradient(
            colors: [Brand.blue.opacity(0.08), Brand.pink.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Mesh-style gradient for backgrounds
        static let meshBackground = LinearGradient(
            colors: [
                Colors.background,
                Brand.blue.opacity(0.03),
                Brand.pink.opacity(0.02),
                Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle gradient
        static let subtle = LinearGradient(
            colors: [Color.white, Color(hex: "F3F4F6")],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Success gradient
        static let success = LinearGradient(
            colors: [Color(hex: "34C759"), Color(hex: "30D158")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography (SF Pro Rounded for playful feel)
    /// Supports Dynamic Type for accessibility

    enum Fonts {
        // Display - for hero text (Rounded for playful feel)
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)

        // Body text - using default design for readability
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)

        // Labels & Captions (Rounded for UI elements)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)

        // Buttons (Rounded for playful CTAs)
        static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let buttonSmall = Font.system(size: 15, weight: .semibold, design: .rounded)
    }

    // MARK: - Spacing (8pt grid system)

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius (Partiful-style generous rounding)

    enum CornerRadius {
        static let xs: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
        static let full: CGFloat = 9999  // Pill shape
    }

    // MARK: - Shadows (Subtle, layered)

    enum Shadows {
        static func small(_ colorScheme: ColorScheme) -> some View {
            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04)
        }

        static func medium(_ colorScheme: ColorScheme) -> some View {
            Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08)
        }

        static func large(_ colorScheme: ColorScheme) -> some View {
            Color.black.opacity(colorScheme == .dark ? 0.5 : 0.12)
        }
    }

    // MARK: - Shadow Styles

    enum Shadow {
        static let sm = ShadowStyle(color: .black.opacity(0.04), radius: 4, y: 2)
        static let md = ShadowStyle(color: .black.opacity(0.08), radius: 12, y: 4)
        static let lg = ShadowStyle(color: .black.opacity(0.12), radius: 24, y: 8)

        // Colored shadows for buttons
        static let primaryGlow = ShadowStyle(color: Brand.blue.opacity(0.3), radius: 16, y: 6)
        static let accentGlow = ShadowStyle(color: Brand.pink.opacity(0.25), radius: 16, y: 6)
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Layout

    enum Layout {
        static let maxContentWidth: CGFloat = 428  // iPhone 14 Pro Max width
        static let buttonHeight: CGFloat = 56
        static let buttonHeightSmall: CGFloat = 44
        static let inputHeight: CGFloat = 52
        static let tabBarHeight: CGFloat = 84
        static let cardMinHeight: CGFloat = 80
    }
}

// MARK: - Shadow Style Helper

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

extension View {
    /// Card style with shadow
    func ouestCard() -> some View {
        self
            .background(OuestTheme.Colors.cardBackground)
            .cornerRadius(OuestTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    /// Elevated card with stronger shadow
    func ouestCardElevated() -> some View {
        self
            .background(OuestTheme.Colors.cardBackground)
            .cornerRadius(OuestTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
    }

    /// Gradient background
    func ouestGradientBackground() -> some View {
        self.background(OuestTheme.Gradients.ouest)
    }

    /// Apply shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Adaptive Colors (respects color scheme)

extension OuestTheme.Colors {
    @MainActor
    static func adaptive(_ colorScheme: ColorScheme) -> AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    struct AdaptiveColors {
        let colorScheme: ColorScheme

        var text: Color {
            colorScheme == .dark ? Dark.text : OuestTheme.Colors.text
        }

        var textPrimary: Color {
            colorScheme == .dark ? Dark.textPrimary : OuestTheme.Colors.textPrimary
        }

        var textSecondary: Color {
            colorScheme == .dark ? Dark.textSecondary : OuestTheme.Colors.textSecondary
        }

        var textTertiary: Color {
            colorScheme == .dark ? Dark.textTertiary : OuestTheme.Colors.textTertiary
        }

        var background: Color {
            colorScheme == .dark ? Dark.background : OuestTheme.Colors.background
        }

        var backgroundSecondary: Color {
            colorScheme == .dark ? Dark.backgroundSecondary : OuestTheme.Colors.backgroundSecondary
        }

        var card: Color {
            colorScheme == .dark ? Dark.card : OuestTheme.Colors.card
        }

        var cardBackground: Color {
            colorScheme == .dark ? Dark.cardBackground : OuestTheme.Colors.cardBackground
        }

        var cardElevated: Color {
            colorScheme == .dark ? Dark.cardElevated : OuestTheme.Colors.cardElevated
        }

        var inputBackground: Color {
            colorScheme == .dark ? Dark.inputBackground : OuestTheme.Colors.inputBackground
        }

        var inputBorder: Color {
            colorScheme == .dark ? Dark.inputBorder : OuestTheme.Colors.inputBorder
        }

        var border: Color {
            colorScheme == .dark ? Dark.border : OuestTheme.Colors.border
        }

        var divider: Color {
            colorScheme == .dark ? Dark.divider : OuestTheme.Colors.divider
        }
    }
}
