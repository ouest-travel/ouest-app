import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 48))
                        .foregroundStyle(.primary)

                    Text("Ouest")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Plan. Share. Explore.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Form
                VStack(spacing: 16) {
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

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }

                // Actions
                VStack(spacing: 12) {
                    OuestButton(title: "Sign In", isLoading: authViewModel.isLoading) {
                        Task {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }

                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Sign up link
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 24)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
