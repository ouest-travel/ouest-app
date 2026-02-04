import SwiftUI

struct OuestTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var icon: String? = nil
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text(label)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            // Input field
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isFocused ? OuestTheme.Colors.primary : OuestTheme.Colors.textSecondary)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .font(OuestTheme.Fonts.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(OuestTheme.Colors.inputBackground)
            .cornerRadius(OuestTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.error)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return OuestTheme.Colors.error
        }
        return isFocused ? OuestTheme.Colors.primary : OuestTheme.Colors.border
    }
}

// MARK: - Text Area (Multiline)

struct OuestTextArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100
    var errorMessage: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(OuestTheme.Fonts.body)
                        .foregroundColor(OuestTheme.Colors.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(OuestTheme.Fonts.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
            }
            .background(OuestTheme.Colors.inputBackground)
            .cornerRadius(OuestTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )

            if let error = errorMessage {
                Text(error)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.error)
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return OuestTheme.Colors.error
        }
        return isFocused ? OuestTheme.Colors.primary : OuestTheme.Colors.border
    }
}

// MARK: - Number Input

struct OuestNumberField: View {
    let label: String
    let placeholder: String
    @Binding var value: Decimal?
    var currencySymbol: String? = nil
    var errorMessage: String? = nil

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(OuestTheme.Fonts.caption)
                .foregroundColor(OuestTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                if let symbol = currencySymbol {
                    Text(symbol)
                        .font(OuestTheme.Fonts.headline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }

                TextField(placeholder, text: $textValue)
                    .focused($isFocused)
                    .keyboardType(.decimalPad)
                    .font(OuestTheme.Fonts.body)
                    .onChange(of: textValue) { _, newValue in
                        value = CurrencyFormatter.parse(newValue)
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(OuestTheme.Colors.inputBackground)
            .cornerRadius(OuestTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: OuestTheme.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )

            if let error = errorMessage {
                Text(error)
                    .font(OuestTheme.Fonts.caption)
                    .foregroundColor(OuestTheme.Colors.error)
            }
        }
        .onAppear {
            if let value = value {
                textValue = "\(value)"
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return OuestTheme.Colors.error
        }
        return isFocused ? OuestTheme.Colors.primary : OuestTheme.Colors.border
    }
}

#Preview {
    VStack(spacing: 20) {
        OuestTextField(
            label: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            icon: "envelope"
        )

        OuestTextField(
            label: "Password",
            placeholder: "Enter password",
            text: .constant(""),
            isSecure: true,
            icon: "lock"
        )

        OuestTextField(
            label: "With Error",
            placeholder: "Enter text",
            text: .constant(""),
            errorMessage: "This field is required"
        )

        OuestTextArea(
            label: "Description",
            placeholder: "Enter a description...",
            text: .constant("")
        )

        OuestNumberField(
            label: "Budget",
            placeholder: "0.00",
            value: .constant(nil),
            currencySymbol: "$"
        )
    }
    .padding()
}
