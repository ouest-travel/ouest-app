import SwiftUI

struct AuthNavigationView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xl) {
                    // Logo / Header
                    VStack(spacing: OuestTheme.Spacing.md) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(OuestTheme.Gradients.primary)

                        Text("Ouest")
                            .font(OuestTheme.Fonts.largeTitle)
                            .foregroundColor(OuestTheme.Colors.text)

                        Text("Plan trips together")
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                    .padding(.top, OuestTheme.Spacing.xxl)

                    // Form
                    VStack(spacing: OuestTheme.Spacing.md) {
                        OuestTextField(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                            icon: "envelope"
                        )

                        OuestTextField(
                            label: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            isSecure: true,
                            icon: "lock"
                        )

                        if let error = errorMessage {
                            Text(error)
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        OuestButton(
                            "Sign In",
                            isLoading: isLoading,
                            isFullWidth: true
                        ) {
                            signIn()
                        }
                    }
                    .padding(.top, OuestTheme.Spacing.lg)

                    // Sign Up Link
                    NavigationLink(destination: SignUpView()) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(OuestTheme.Colors.textSecondary)

                            Text("Sign Up")
                                .foregroundColor(OuestTheme.Colors.primary)
                                .fontWeight(.semibold)
                        }
                        .font(OuestTheme.Fonts.subheadline)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)
            }
        }
        .navigationBarHidden(true)
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch {
                errorMessage = "Invalid email or password"
            }
            isLoading = false
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: OuestTheme.Spacing.xl) {
                    // Header
                    VStack(spacing: OuestTheme.Spacing.sm) {
                        Text("Create Account")
                            .font(OuestTheme.Fonts.title)
                            .foregroundColor(OuestTheme.Colors.text)

                        Text("Start planning your adventures")
                            .font(OuestTheme.Fonts.subheadline)
                            .foregroundColor(OuestTheme.Colors.textSecondary)
                    }
                    .padding(.top, OuestTheme.Spacing.lg)

                    // Form
                    VStack(spacing: OuestTheme.Spacing.md) {
                        OuestTextField(
                            label: "Display Name",
                            placeholder: "Enter your name",
                            text: $displayName,
                            icon: "person"
                        )

                        OuestTextField(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                            icon: "envelope"
                        )

                        OuestTextField(
                            label: "Password",
                            placeholder: "Create a password",
                            text: $password,
                            isSecure: true,
                            icon: "lock"
                        )

                        OuestTextField(
                            label: "Confirm Password",
                            placeholder: "Confirm your password",
                            text: $confirmPassword,
                            isSecure: true,
                            icon: "lock.fill"
                        )

                        if let error = errorMessage {
                            Text(error)
                                .font(OuestTheme.Fonts.caption)
                                .foregroundColor(OuestTheme.Colors.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        OuestButton(
                            "Create Account",
                            isLoading: isLoading,
                            isFullWidth: true
                        ) {
                            signUp()
                        }
                    }
                    .padding(.top, OuestTheme.Spacing.md)

                    // Sign In Link
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(OuestTheme.Colors.textSecondary)

                            Text("Sign In")
                                .foregroundColor(OuestTheme.Colors.primary)
                                .fontWeight(.semibold)
                        }
                        .font(OuestTheme.Fonts.subheadline)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        // Validation
        guard !displayName.isEmpty else {
            errorMessage = "Please enter your name"
            return
        }

        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    displayName: displayName
                )
            } catch {
                errorMessage = "Failed to create account. Please try again."
            }
            isLoading = false
        }
    }
}

#Preview("Login") {
    AuthNavigationView()
        .environmentObject(AuthManager())
        .environmentObject(DemoModeManager())
        .environmentObject(ThemeManager())
}

#Preview("Sign Up") {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthManager())
            .environmentObject(DemoModeManager())
            .environmentObject(ThemeManager())
    }
}
