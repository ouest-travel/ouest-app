import SwiftUI

struct OuestCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = OuestTheme.Spacing.md

    init(padding: CGFloat = OuestTheme.Spacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(OuestTheme.Colors.cardBackground)
            .cornerRadius(OuestTheme.CornerRadius.large)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Pressable Card (Tappable)

struct OuestPressableCard<Content: View>: View {
    let content: Content
    let action: () -> Void
    var padding: CGFloat = OuestTheme.Spacing.md

    @State private var isPressed = false

    init(padding: CGFloat = OuestTheme.Spacing.md, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(padding)
                .background(OuestTheme.Colors.cardBackground)
                .cornerRadius(OuestTheme.CornerRadius.large)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Gradient Card

struct OuestGradientCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient
    var padding: CGFloat = OuestTheme.Spacing.md

    init(
        gradient: LinearGradient = OuestTheme.Gradients.primary,
        padding: CGFloat = OuestTheme.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(gradient)
            .cornerRadius(OuestTheme.CornerRadius.large)
            .shadow(color: OuestTheme.Colors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Section Card with Header

struct OuestSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionLabel = actionLabel
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OuestTheme.Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(OuestTheme.Colors.text)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                if let action = action, let label = actionLabel {
                    Button(action: action) {
                        Text(label)
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(OuestTheme.Colors.primary)
                    }
                }
            }

            content
        }
        .padding(OuestTheme.Spacing.md)
        .background(OuestTheme.Colors.cardBackground)
        .cornerRadius(OuestTheme.CornerRadius.large)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            OuestCard {
                Text("Basic Card")
                    .frame(maxWidth: .infinity)
            }

            OuestPressableCard(action: { print("Tapped") }) {
                Text("Pressable Card - Tap me!")
                    .frame(maxWidth: .infinity)
            }

            OuestGradientCard {
                Text("Gradient Card")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }

            OuestSectionCard(
                title: "Section Title",
                subtitle: "Optional subtitle",
                action: { print("View all") },
                actionLabel: "View All"
            ) {
                Text("Section content goes here")
            }
        }
        .padding()
    }
    .background(OuestTheme.Colors.background)
}
