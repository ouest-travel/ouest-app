import SwiftUI
import AuthenticationServices

struct AuthNavigationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var signInCoordinator = AppleSignInCoordinator()

    private var viewModel: AuthViewModel {
        appState.authViewModel
    }

    var body: some View {
        ZStack {
            OuestTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: OuestTheme.Spacing.xl) {
                Spacer()

                // Logo / Header
                VStack(spacing: OuestTheme.Spacing.md) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(OuestTheme.Gradients.primary)

                    Text("Ouest")
                        .font(OuestTheme.Fonts.largeTitle)
                        .foregroundColor(OuestTheme.Colors.text)

                    Text("Plan trips together")
                        .font(OuestTheme.Fonts.subheadline)
                        .foregroundColor(OuestTheme.Colors.textSecondary)
                }

                Spacer()

                // Sign In Buttons
                VStack(spacing: OuestTheme.Spacing.md) {
                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(OuestTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Sign in with Apple Button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            Task {
                                await viewModel.handleAppleSignIn(result: result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(OuestTheme.Radius.md)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    // Loading indicator
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, OuestTheme.Spacing.sm)
                    }
                }
                .padding(.horizontal, OuestTheme.Spacing.xl)

                // Demo Mode Button
                Button {
                    appState.isDemoMode = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                        Text("Try Demo Mode")
                    }
                    .font(OuestTheme.Fonts.subheadline)
                    .foregroundColor(OuestTheme.Colors.primary)
                }
                .padding(.top, OuestTheme.Spacing.md)

                Spacer()

                // Terms and Privacy
                VStack(spacing: OuestTheme.Spacing.xs) {
                    Text("By continuing, you agree to our")
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.textSecondary)

                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // Open Terms URL
                        }
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.primary)

                        Text("and")
                            .font(OuestTheme.Fonts.caption)
                            .foregroundColor(OuestTheme.Colors.textSecondary)

                        Button("Privacy Policy") {
                            // Open Privacy URL
                        }
                        .font(OuestTheme.Fonts.caption)
                        .foregroundColor(OuestTheme.Colors.primary)
                    }
                }
                .padding(.bottom, OuestTheme.Spacing.xl)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.error) { _, _ in
            // Clear error after 5 seconds
            if viewModel.error != nil {
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    viewModel.clearError()
                }
            }
        }
    }
}

#Preview("Login") {
    AuthNavigationView()
        .environmentObject(AppState(isDemoMode: false))
}
