import SwiftUI

enum OuestButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive
}

enum OuestButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }

    var font: Font {
        switch self {
        case .small: return OuestTheme.Fonts.caption
        case .medium: return OuestTheme.Fonts.callout
        case .large: return OuestTheme.Fonts.headline
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 24
        }
    }
}

struct OuestButton: View {
    let title: String
    let style: OuestButtonStyle
    let size: OuestButtonSize
    let isLoading: Bool
    let isFullWidth: Bool
    let icon: String?
    let action: () -> Void

    init(
        _ title: String,
        style: OuestButtonStyle = .primary,
        size: OuestButtonSize = .medium,
        isLoading: Bool = false,
        isFullWidth: Bool = false,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(size.font)
                    }
                    Text(title)
                        .font(size.font.weight(.semibold))
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(background)
            .cornerRadius(OuestTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1.5 : 0)
            )
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return OuestTheme.Colors.primary
        case .ghost:
            return OuestTheme.Colors.text
        case .destructive:
            return .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            OuestTheme.Gradients.primary
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
            return OuestTheme.Colors.primary
        default:
            return .clear
        }
    }
}

// MARK: - Icon-Only Button

struct OuestIconButton: View {
    let icon: String
    let style: OuestButtonStyle
    let size: CGFloat
    let action: () -> Void

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
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(background)
                .cornerRadius(size / 2)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary, .ghost:
            return OuestTheme.Colors.text
        case .destructive:
            return OuestTheme.Colors.error
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            OuestTheme.Gradients.primary
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(OuestTheme.Gradients.primary)
                .cornerRadius(28)
                .shadow(color: OuestTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        OuestButton("Primary Button", style: .primary, action: {})
        OuestButton("Secondary Button", style: .secondary, action: {})
        OuestButton("Ghost Button", style: .ghost, action: {})
        OuestButton("Destructive", style: .destructive, action: {})
        OuestButton("Loading", isLoading: true, action: {})
        OuestButton("With Icon", icon: "plus", action: {})
        OuestButton("Full Width", isFullWidth: true, action: {})

        HStack {
            OuestIconButton(icon: "plus", style: .primary, action: {})
            OuestIconButton(icon: "pencil", style: .ghost, action: {})
        }

        OuestFAB(icon: "plus", action: {})
    }
    .padding()
}
