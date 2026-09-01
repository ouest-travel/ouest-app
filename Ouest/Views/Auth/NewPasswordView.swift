import SwiftUI

/// Presented when the user lands on the app via a password-recovery
/// Universal Link (Supabase `type=recovery`). The session already exists at
/// this point — its only permitted action is `auth.update(user:)` with a new
/// password. Once that succeeds, AuthViewModel clears `isPasswordRecovery`
/// and ContentView returns the user to the normal Main / Onboarding flow.
struct NewPasswordView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var isTooShort: Bool {
        !password.isEmpty && password.count < 8
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 48))
                    .foregroundStyle(OuestTheme.Colors.brand)

                Text("Set a New Password")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Pick something you'll remember this time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(spacing: 16) {
                OuestTextField(
                    text: $password,
                    placeholder: "New password",
                    isSecure: true
                )

                OuestTextField(
                    text: $confirmPassword,
                    placeholder: "Confirm new password",
                    isSecure: true
                )

                if isTooShort {
                    Text("Password must be at least 8 characters")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords don't match")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            OuestButton(
                title: "Update Password",
                isLoading: authViewModel.isLoading
            ) {
                guard passwordsMatch, !isTooShort else { return }
                Task {
                    await authViewModel.updatePassword(newPassword: password)
                }
            }
            .disabled(!passwordsMatch || isTooShort)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    NewPasswordView()
        .environment(AuthViewModel())
}
