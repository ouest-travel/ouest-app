import SwiftUI

struct OuestTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var hasError: Bool = false

    @FocusState private var isFocused: Bool
    @State private var isRevealed: Bool = false

    var body: some View {
        HStack(spacing: OuestTheme.Spacing.sm) {
            Group {
                if isSecure && !isRevealed {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else if isSecure {
                    // Revealed password: force the typing modifiers that
                    // SecureField applies implicitly so toggling doesn't
                    // auto-capitalize or offer corrections mid-password.
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isFocused)
                } else {
                    // Autocapitalization and autocorrection intentionally left at
                    // SwiftUI defaults (.sentences + on). Fields that need a
                    // different behavior — email, handle, invite code — apply
                    // the modifier at the call site.
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                }
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
            }
        }
        .padding(.horizontal, OuestTheme.Spacing.lg)
        .frame(height: 50)
        .background(OuestTheme.Colors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: OuestTheme.Radius.md)
                .stroke(borderColor, lineWidth: isFocused || hasError ? 1.5 : 0)
        )
        .animation(OuestTheme.Anim.quick, value: isFocused)
        .animation(OuestTheme.Anim.quick, value: hasError)
    }

    private var borderColor: Color {
        if hasError { return OuestTheme.Colors.error }
        if isFocused { return OuestTheme.Colors.brand }
        return .clear
    }
}

#Preview {
    VStack(spacing: 16) {
        OuestTextField(text: .constant(""), placeholder: "Email")
        OuestTextField(text: .constant(""), placeholder: "Password", isSecure: true)
        OuestTextField(text: .constant("Error"), placeholder: "Error field", hasError: true)
    }
    .padding()
}

#Preview("Dark") {
    VStack(spacing: 16) {
        OuestTextField(text: .constant(""), placeholder: "Email")
        OuestTextField(text: .constant(""), placeholder: "Password", isSecure: true)
        OuestTextField(text: .constant("Error"), placeholder: "Error field", hasError: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
