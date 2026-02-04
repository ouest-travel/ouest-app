import SwiftUI

// MARK: - Button Styles

enum OuestButtonStyle {
    case primary       // Gradient background, white text
    case secondary     // Outlined with primary color
    case ghost         // Subtle background
    case destructive   // Red for dangerous actions
    case accent        // Pink gradient for special actions
}

enum OuestButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 50
        case .large: return 56
        }
    }

    var font: Font {
        switch self {
        case .small: return OuestTheme.Fonts.buttonSmall
        case .medium: return OuestTheme.Fonts.button
        case .large: return OuestTheme.Fonts.button
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 20
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 24
        case .large: return 32
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return OuestTheme.CornerRadius.medium
        case .medium: return OuestTheme.CornerRadius.large
        case .large: return OuestTheme.CornerRadius.xl
        }
    }
}

// MARK: - Main Button Component

struct OuestButton: View {
    let title: String
    let style: OuestButtonStyle
    let size: OuestButtonSize
    let isLoading: Bool
    let isFullWidth: Bool
    let icon: String?
    let iconPosition: IconPosition
    let action: () -> Void

    enum IconPosition {
        case leading
        case trailing
    }

    @State private var isPressed = false

    init(
        _ title: String,
        style: OuestButtonStyle = .primary,
        size: OuestButtonSize = .medium,
        isLoading: Bool = false,
        isFullWidth: Bool = false,
        icon: String? = nil,
        iconPosition: IconPosition = .leading,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.icon = icon
        self.iconPosition = iconPosition
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: OuestTheme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.9)
                } else {
                    if let icon = icon, iconPosition == .leading {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }

                    Text(title)
                        .font(size.font)

                    if let icon = icon, iconPosition == .trailing {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .secondary ? 2 : 0)
            )
            .shadow(shadowStyle)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(OuestTheme.Animation.quick, value: isPressed)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Styling

    private var foregroundColor: Color {
        switch style {
        case .primary, .accent, .destructive:
            return .white
        case .secondary:
            return OuestTheme.Colors.primary
        case .ghost:
            return OuestTheme.Colors.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            OuestTheme.Gradients.primary
        case .accent:
            LinearGradient(
                colors: [OuestTheme.Brand.pink, OuestTheme.Brand.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Color.clear
        case .ghost:
            OuestTheme.Colors.inputBackground
        case .destructive:
            OuestTheme.Colors.error
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return OuestTheme.Colors.primary.opacity(0.3)
        default:
            return .clear
        }
    }

    private var shadowStyle: ShadowStyle {
        switch style {
        case .primary:
            return isPressed ? OuestTheme.Shadow.sm : OuestTheme.Shadow.primaryGlow
        case .accent:
            return isPressed ? OuestTheme.Shadow.sm : OuestTheme.Shadow.accentGlow
        default:
            return OuestTheme.Shadow.sm
        }
    }
}

// MARK: - Pill Button (Compact, fully rounded)

struct OuestPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OuestTheme.Fonts.buttonSmall)
                .foregroundColor(isSelected ? .white : OuestTheme.Colors.textSecondary)
                .padding(.horizontal, OuestTheme.Spacing.md)
                .padding(.vertical, OuestTheme.Spacing.xs)
                .background(
                    isSelected
                        ? AnyView(OuestTheme.Gradients.primary)
                        : AnyView(OuestTheme.Colors.inputBackground)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Icon Button

struct OuestIconButton: View {
    let icon: String
    let style: OuestButtonStyle
    let size: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    init(
        icon: String,
        style: OuestButtonStyle = .ghost,
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(OuestTheme.Animation.quick, value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(icon)
        .accessibilityAddTraits(.isButton)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .accent:
            return .white
        case .secondary, .ghost:
            return OuestTheme.Colors.textPrimary
        case .destructive:
            return OuestTheme.Colors.error
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            OuestTheme.Gradients.primary
        case .accent:
            LinearGradient(
                colors: [OuestTheme.Brand.pink, OuestTheme.Brand.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .ghost:
            OuestTheme.Colors.inputBackground
        default:
            Color.clear
        }
    }
}

// MARK: - Floating Action Button

struct OuestFAB: View {
    let icon: String
    let style: OuestButtonStyle
    let action: () -> Void

    @State private var isPressed = false

    init(
        icon: String,
        style: OuestButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(background)
                .clipShape(Circle())
                .shadow(OuestTheme.Shadow.primaryGlow)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(OuestTheme.Animation.bouncy, value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Add")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .accent:
            LinearGradient(
                colors: [OuestTheme.Brand.pink, OuestTheme.Brand.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            OuestTheme.Gradients.primary
        }
    }
}

// MARK: - Text Button (Link-style)

struct OuestTextButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    init(
        _ title: String,
        color: Color = OuestTheme.Colors.primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OuestTheme.Fonts.buttonSmall)
                .foregroundColor(color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            // Primary buttons
            VStack(spacing: 12) {
                Text("Primary").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                OuestButton("Get Started", style: .primary, size: .large, isFullWidth: true, action: {})
                OuestButton("Continue", style: .primary, icon: "arrow.right", iconPosition: .trailing, action: {})
            }

            // Accent buttons
            VStack(spacing: 12) {
                Text("Accent").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                OuestButton("Create Trip", style: .accent, icon: "plus", action: {})
            }

            // Secondary & Ghost
            VStack(spacing: 12) {
                Text("Secondary & Ghost").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                OuestButton("Secondary Button", style: .secondary, action: {})
                OuestButton("Ghost Button", style: .ghost, action: {})
            }

            // States
            VStack(spacing: 12) {
                Text("States").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                OuestButton("Loading...", isLoading: true, action: {})
                OuestButton("Delete", style: .destructive, icon: "trash", action: {})
            }

            // Pill buttons
            VStack(spacing: 12) {
                Text("Pills").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                HStack {
                    OuestPillButton(title: "All", isSelected: true, action: {})
                    OuestPillButton(title: "Active", isSelected: false, action: {})
                    OuestPillButton(title: "Past", isSelected: false, action: {})
                }
            }

            // Icon buttons
            VStack(spacing: 12) {
                Text("Icons").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                HStack(spacing: 16) {
                    OuestIconButton(icon: "plus", style: .primary, action: {})
                    OuestIconButton(icon: "pencil", style: .ghost, action: {})
                    OuestIconButton(icon: "heart.fill", style: .accent, action: {})
                }
            }

            // FAB
            VStack(spacing: 12) {
                Text("FAB").font(OuestTheme.Fonts.caption).foregroundColor(OuestTheme.Colors.textSecondary)
                HStack(spacing: 16) {
                    OuestFAB(icon: "plus", action: {})
                    OuestFAB(icon: "plus", style: .accent, action: {})
                }
            }
        }
        .padding(24)
    }
    .background(OuestTheme.Colors.background)
}
