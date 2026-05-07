import SwiftUI

/// Lets a user manually enter an 8-character trip invite code.
/// Useful when a shared link wasn't tappable in their messaging app.
struct JoinWithCodeSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var navigateToJoin = false
    @FocusState private var fieldFocused: Bool

    /// Codes are 8 chars, but accept slight variations (we filter to 4–10 chars)
    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidLength: Bool {
        trimmedCode.count >= 4 && trimmedCode.count <= 10
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: OuestTheme.Spacing.xl)

                // Icon
                ZStack {
                    Circle()
                        .fill(OuestTheme.Colors.brandLight)
                        .frame(width: 88, height: 88)
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(OuestTheme.Colors.brandGradient)
                }
                .padding(.bottom, OuestTheme.Spacing.xl)

                // Title + subtitle
                VStack(spacing: OuestTheme.Spacing.sm) {
                    Text("Got an invite code?")
                        .font(OuestTheme.Typography.screenTitle)
                        .foregroundStyle(OuestTheme.Colors.textPrimary)

                    Text("Enter the code your friend shared with you to join their trip.")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OuestTheme.Spacing.xl)
                }
                .padding(.bottom, OuestTheme.Spacing.xxxl)

                // Code field
                TextField("", text: $code, prompt: Text("ABCD1234").foregroundColor(OuestTheme.Colors.textSecondary.opacity(0.5)))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($fieldFocused)
                    .padding(.vertical, OuestTheme.Spacing.lg)
                    .padding(.horizontal, OuestTheme.Spacing.xl)
                    .background(OuestTheme.Colors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                    .padding(.horizontal, OuestTheme.Spacing.xl)
                    .onChange(of: code) { _, newValue in
                        // Sanitize: uppercase + alphanumeric only + max 10 chars
                        let cleaned = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        if cleaned != newValue {
                            code = String(cleaned.prefix(10))
                        } else if cleaned.count > 10 {
                            code = String(cleaned.prefix(10))
                        }
                    }
                    .onSubmit {
                        if isValidLength { navigateToJoin = true }
                    }

                Text("8-character code, no spaces")
                    .font(OuestTheme.Typography.micro)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                    .padding(.top, OuestTheme.Spacing.sm)

                Spacer()

                // Continue button
                OuestButton(title: "Continue") {
                    HapticFeedback.light()
                    navigateToJoin = true
                }
                .disabled(!isValidLength)
                .opacity(isValidLength ? 1 : 0.5)
                .padding(.horizontal, OuestTheme.Spacing.xl)
                .padding(.bottom, OuestTheme.Spacing.lg)

                // Paste from clipboard helper
                Button {
                    if let pasted = UIPasteboard.general.string {
                        let cleaned = pasted.uppercased().filter { $0.isLetter || $0.isNumber }
                        // If user pasted a full URL, extract trailing path
                        if cleaned.count >= 4 && cleaned.count <= 12 {
                            code = String(cleaned.prefix(10))
                        } else if pasted.contains("/join/") {
                            // Try to extract code from URL
                            if let range = pasted.range(of: "/join/") {
                                let after = pasted[range.upperBound...]
                                let extracted = after.split(separator: "/").first
                                    ?? after.split(separator: "?").first
                                    ?? Substring(after)
                                code = String(extracted).uppercased()
                                    .filter { $0.isLetter || $0.isNumber }
                                    .prefix(10).description
                            }
                        }
                        HapticFeedback.selection()
                    }
                } label: {
                    Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                        .font(OuestTheme.Typography.caption)
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
                .padding(.bottom, OuestTheme.Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .background(Color("Background"))
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(OuestTheme.Colors.brand)
                }
            }
            .navigationDestination(isPresented: $navigateToJoin) {
                JoinTripView(inviteCode: trimmedCode)
            }
            .onAppear {
                // Auto-focus the field after a brief delay so the keyboard slides up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    fieldFocused = true
                }
            }
        }
    }
}

#Preview {
    JoinWithCodeSheet()
}
