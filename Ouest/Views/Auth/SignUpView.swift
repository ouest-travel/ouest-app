import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Start planning your next adventure")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(spacing: 16) {
                OuestTextField(text: $fullName, placeholder: "Full Name")

                OuestTextField(
                    text: $email,
                    placeholder: "Email",
                    keyboardType: .emailAddress
                )

                OuestTextField(
                    text: $password,
                    placeholder: "Password",
                    isSecure: true
                )

                OuestTextField(
                    text: $confirmPassword,
                    placeholder: "Confirm Password",
                    isSecure: true
                )

                if !confirmPassword.isEmpty && !passwordsMatch {
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
                title: "Create Account",
                isLoading: authViewModel.isLoading
            ) {
                guard passwordsMatch else { return }
                Task {
                    await authViewModel.signUp(
                        email: email,
                        password: password,
                        fullName: fullName
                    )
                }
            }
            .disabled(!passwordsMatch || email.isEmpty || fullName.isEmpty)

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarBackButtonHidden(false)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environment(AuthViewModel())
    }
}
