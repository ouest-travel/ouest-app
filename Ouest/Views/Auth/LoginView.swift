import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @State private var appeared = false
    @State private var hasError = false
    /// Raw nonce for the in-flight Sign in with Apple request. Generated in
    /// SignInWithAppleButton's onRequest closure, consumed by onCompletion
    /// so AuthViewModel can hand it to Supabase for identity-token verification.
    @State private var appleRawNonce = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: OuestTheme.Spacing.xxxl) {
                Spacer()

                // Logo
                VStack(spacing: OuestTheme.Spacing.sm) {
                    Image("OuestLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.lg))
                        .bouncyAppear(isVisible: appeared, delay: 0)

                    Text("Ouest")
                        .font(OuestTheme.Typography.heroTitle)
                        .fadeSlideIn(isVisible: appeared, delay: 0.1)

                    Text("Simplify, Trip & Track")
                        .font(.subheadline)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                        .fadeSlideIn(isVisible: appeared, delay: 0.15)
                }

                // Form
                VStack(spacing: OuestTheme.Spacing.lg) {
                    OuestTextField(
                        text: $email,
                        placeholder: "Email",
                        keyboardType: .emailAddress,
                        hasError: authViewModel.errorMessage != nil
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fadeSlideIn(isVisible: appeared, delay: 0.2)

                    OuestTextField(
                        text: $password,
                        placeholder: "Password",
                        isSecure: true,
                        hasError: authViewModel.errorMessage != nil
                    )
                    .fadeSlideIn(isVisible: appeared, delay: 0.25)

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(OuestTheme.Typography.caption)
                            .foregroundStyle(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .shakeOnError(hasError)

                // Actions
                VStack(spacing: OuestTheme.Spacing.md) {
                    OuestButton(title: "Sign In", isLoading: authViewModel.isLoading) {
                        HapticFeedback.light()
                        Task {
                            await authViewModel.signIn(email: email, password: password)
                            if authViewModel.errorMessage != nil {
                                hasError.toggle()
                                HapticFeedback.error()
                            }
                        }
                    }

                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundStyle(OuestTheme.Colors.textSecondary)
                }
                .fadeSlideIn(isVisible: appeared, delay: 0.3)

                // Divider
                HStack(spacing: OuestTheme.Spacing.md) {
                    Rectangle()
                        .fill(OuestTheme.Colors.surfaceTertiary)
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Rectangle()
                        .fill(OuestTheme.Colors.surfaceTertiary)
                        .frame(height: 1)
                }
                .fadeSlideIn(isVisible: appeared, delay: 0.32)

                // Apple Sign In — use Apple's native SwiftUI button so the
                // styling is HIG-compliant by construction. The custom
                // Button we had before used .background(.black), which was
                // invisible on the app's dark login screen and triggered a
                // Guideline 4.0 review rejection (reviewer screenshot on
                // iPad Air showed just a floating logo + text).
                SignInWithAppleButton(.signIn) { request in
                    HapticFeedback.light()
                    let nonce = AppleSignInCoordinator.randomNonceString()
                    appleRawNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInCoordinator.sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            await authViewModel.completeAppleSignIn(
                                authorization: authorization,
                                rawNonce: appleRawNonce
                            )
                        }
                    case .failure(let error):
                        // Silent on explicit user cancel; surface anything else.
                        if let authError = error as? ASAuthorizationError,
                           authError.code == .canceled {
                            return
                        }
                        authViewModel.errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: OuestTheme.Radius.md))
                .fadeSlideIn(isVisible: appeared, delay: 0.34)

                Spacer()

                // Sign up link
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(OuestTheme.Colors.textSecondary)
                    Button("Sign Up") {
                        HapticFeedback.selection()
                        showSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .fadeSlideIn(isVisible: appeared, delay: 0.35)

                #if DEBUG
                // Dev sign-in — visible only in debug builds
                Button {
                    HapticFeedback.medium()
                    Task { await authViewModel.devSignIn() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.caption)
                        Text("Dev Sign In")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, OuestTheme.Spacing.lg)
                    .padding(.vertical, OuestTheme.Spacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: OuestTheme.Radius.sm)
                            .stroke(.orange.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .padding(.bottom, OuestTheme.Spacing.sm)
                .fadeSlideIn(isVisible: appeared, delay: 0.4)
                #endif
            }
            .padding(.horizontal, OuestTheme.Spacing.xxl)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .onAppear {
                withAnimation {
                    appeared = true
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
