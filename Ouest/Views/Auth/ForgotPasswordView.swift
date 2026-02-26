import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var emailSent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if emailSent {
                    VStack(spacing: 16) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Check Your Email")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("We've sent a password reset link to \(email)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        OuestButton(title: "Done") {
                            dismiss()
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Reset Password")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Enter your email and we'll send you a reset link")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    OuestTextField(
                        text: $email,
                        placeholder: "Email",
                        keyboardType: .emailAddress
                    )

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    OuestButton(title: "Send Reset Link", isLoading: authViewModel.isLoading) {
                        Task {
                            await authViewModel.resetPassword(email: email)
                            emailSent = true
                        }
                    }
                    .disabled(email.isEmpty)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environment(AuthViewModel())
}
