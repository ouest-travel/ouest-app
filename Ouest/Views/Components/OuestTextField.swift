import SwiftUI

struct OuestTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var hasError: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
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
