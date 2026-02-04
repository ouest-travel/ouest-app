import SwiftUI

/// Design system for Ouest app
/// Based on the web app's Tailwind configuration
enum OuestTheme {

    // MARK: - Colors

    enum Colors {
        // Primary brand colors
        static let primary = Color(hex: "3B82F6")         // Blue-500
        static let primaryLight = Color(hex: "60A5FA")    // Blue-400
        static let primaryDark = Color(hex: "2563EB")     // Blue-600

        // Accent colors (from ouest gradient)
        static let pink = Color(hex: "EC4899")            // Pink-500
        static let coral = Color(hex: "F97316")           // Orange-500
        static let indigo = Color(hex: "6366F1")          // Indigo-500

        // Semantic colors
        static let success = Color(hex: "22C55E")         // Green-500
        static let warning = Color(hex: "F59E0B")         // Amber-500
        static let error = Color(hex: "EF4444")           // Red-500

        // Text colors
        static let text = Color(hex: "1F2937")            // Gray-800
        static let textSecondary = Color(hex: "6B7280")   // Gray-500
        static let textTertiary = Color(hex: "9CA3AF")    // Gray-400

        // Background colors
        static let background = Color(hex: "F9FAFB")      // Gray-50
        static let cardBackground = Color.white
        static let inputBackground = Color(hex: "F3F4F6") // Gray-100

        // Border colors
        static let border = Color(hex: "E5E7EB")          // Gray-200
        static let borderFocused = Color(hex: "3B82F6")   // Blue-500

        // Dark mode variants
        enum Dark {
            static let text = Color(hex: "F9FAFB")
            static let textSecondary = Color(hex: "9CA3AF")
            static let background = Color(hex: "111827")      // Gray-900
            static let cardBackground = Color(hex: "1F2937")  // Gray-800
            static let inputBackground = Color(hex: "374151") // Gray-700
            static let border = Color(hex: "374151")
        }

        // Category colors for expenses
        enum Category {
            static let food = Color(hex: "F97316")        // Orange
            static let transport = Color(hex: "3B82F6")   // Blue
            static let stay = Color(hex: "8B5CF6")        // Purple
            static let activities = Color(hex: "22C55E") // Green
            static let other = Color(hex: "6B7280")       // Gray
        }
    }

    // MARK: - Gradients

    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.primary, Colors.indigo],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let ouest = LinearGradient(
            colors: [Colors.pink, Colors.coral, Colors.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let card = LinearGradient(
            colors: [Colors.primary.opacity(0.1), Colors.indigo.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let subtle = LinearGradient(
            colors: [Color.white, Color(hex: "F3F4F6")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Typography

    enum Fonts {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    enum Shadows {
        static func small(_ colorScheme: ColorScheme) -> some View {
            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
        }

        static func medium(_ colorScheme: ColorScheme) -> some View {
            Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1)
        }
    }
}

// MARK: - Color Extension for Hex Support

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
            (a, r, g, b) = (1, 1, 1, 0)
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
    func ouestCard() -> some View {
        self
            .background(OuestTheme.Colors.cardBackground)
            .cornerRadius(OuestTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func ouestGradientBackground() -> some View {
        self.background(OuestTheme.Gradients.ouest)
    }
}
