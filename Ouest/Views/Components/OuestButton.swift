import SwiftUI

struct OuestButton: View {
    let title: String
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }

    var body: some View {
        Button {
            HapticFeedback.light()
            action()
        } label: {
            HStack(spacing: OuestTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundStyle)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
            .ouestElevation(style == .primary ? .md : .sm)
        }
        .disabled(isLoading)
        .pressEffect(scale: 0.97)
        .animation(OuestTheme.Anim.quick, value: isLoading)
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .primary: AnyShapeStyle(OuestTheme.Colors.brandFill)
        case .secondary: AnyShapeStyle(OuestTheme.Colors.surfaceTertiary)
        case .destructive: AnyShapeStyle(OuestTheme.Colors.error)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: OuestTheme.Colors.textPrimary
        case .destructive: .white
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        OuestButton(title: "Primary", action: {})
        OuestButton(title: "Secondary", style: .secondary, action: {})
        OuestButton(title: "Loading", isLoading: true, action: {})
        OuestButton(title: "Delete", style: .destructive, action: {})
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: 16) {
        OuestButton(title: "Primary", action: {})
        OuestButton(title: "Secondary", style: .secondary, action: {})
        OuestButton(title: "Loading", isLoading: true, action: {})
        OuestButton(title: "Delete", style: .destructive, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
}
