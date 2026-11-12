import Foundation
import Supabase

// MARK: - Auth Error Types

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case networkError
    case emailNotConfirmed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password. Please try again."
        case .emailAlreadyExists:
            "An account with this email already exists."
        case .weakPassword:
            "Password is too weak. Use at least 8 characters."
        case .networkError:
            "Unable to connect. Please check your internet connection."
        case .emailNotConfirmed:
            "Please confirm your email address before signing in."
        case .unknown(let message):
            message
        }
    }
}

// MARK: - Auth Service

enum AuthService {

    /// Sign in with email and password
    static func signIn(email: String, password: String) async throws -> Session {
        do {
            return try await SupabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Sign up with email, password, and full name
    /// Returns nil session if email confirmation is required
    static func signUp(email: String, password: String, fullName: String) async throws -> Session? {
        do {
            let response = try await SupabaseManager.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)],
                redirectTo: Self.signUpRedirectURL
            )
            return response.session
        } catch {
            throw mapError(error)
        }
    }

    /// Universal Link the Supabase email-confirmation lands on. Handled by
    /// DeepLinkRouter (`/auth/callback`) → ContentView, which forwards the URL
    /// to `client.auth.session(from:)` to finalize the session in-app.
    ///
    /// Uses `links.ouest.travel` because that's the subdomain actually
    /// pointed at this repo's Vercel deployment (which serves the AASA)
    /// and it's already declared in the app's associated-domains
    /// entitlement. The bare `ouest.travel` domain currently resolves to
    /// a placeholder page at a non-Vercel host, so the redirect would
    /// 404 there.
    ///
    /// NOTE: this URL must ALSO be on the Supabase project's Auth →
    /// URL Configuration → Redirect URLs allowlist — otherwise Supabase
    /// silently falls back to the Site URL and the redirect still lands
    /// on whatever the Site URL is.
    private static let signUpRedirectURL = URL(string: "https://links.ouest.travel/auth/callback")

    /// Sign in with Apple using the identity token from ASAuthorization
    static func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        do {
            return try await SupabaseManager.client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
        } catch {
            throw mapError(error)
        }
    }

    /// Sign out the current user
    static func signOut() async throws {
        try await SupabaseManager.client.auth.signOut()
    }

    /// Permanently delete the current user's account via the `delete-user`
    /// Edge Function (auth.admin.deleteUser; everything else cascades).
    /// Pass a fresh Apple authorization code for Sign in with Apple accounts
    /// so the function can revoke the user's Apple tokens, which Apple
    /// requires on account deletion.
    /// The session is invalid afterwards, so the local sign-out is best-effort.
    static func deleteAccount(appleAuthorizationCode: String? = nil) async throws {
        try await SupabaseManager.client.functions.invoke(
            "delete-user",
            options: .init(body: DeleteAccountPayload(appleAuthorizationCode: appleAuthorizationCode))
        )
        try? await SupabaseManager.client.auth.signOut()
    }

    /// True when the signed-in account has a linked Apple identity.
    static func isAppleAccount() async -> Bool {
        guard let user = try? await SupabaseManager.client.auth.session.user else { return false }
        return user.identities?.contains { $0.provider == "apple" } ?? false
    }

    /// Restore an existing session from Keychain
    static func restoreSession() async throws -> Session {
        try await SupabaseManager.client.auth.session
    }

    /// Send a password reset email. Uses the same Universal Link callback as
    /// signup so tapping the reset link opens the app (not the web) and lands
    /// the user on NewPasswordView to set a fresh password.
    static func resetPassword(email: String) async throws {
        try await SupabaseManager.client.auth.resetPasswordForEmail(
            email,
            redirectTo: Self.signUpRedirectURL
        )
    }

    /// Update the currently-signed-in user's password. Used by NewPasswordView
    /// after a recovery-flow auth callback has established a temporary session
    /// with password-recovery scope.
    static func updatePassword(_ newPassword: String) async throws {
        try await SupabaseManager.client.auth.update(
            user: UserAttributes(password: newPassword)
        )
    }

    /// Fetch the profile for a given user ID
    static func fetchProfile(userId: UUID) async throws -> Profile {
        try await SupabaseManager.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    // MARK: - Error Mapping

    private static func mapError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") ||
           message.contains("invalid_credentials") {
            return .invalidCredentials
        }

        if message.contains("user already registered") ||
           message.contains("already been registered") {
            return .emailAlreadyExists
        }

        if message.contains("password") && (message.contains("weak") || message.contains("short") || message.contains("length")) {
            return .weakPassword
        }

        if message.contains("email not confirmed") ||
           message.contains("email_not_confirmed") {
            return .emailNotConfirmed
        }

        if message.contains("network") ||
           message.contains("offline") ||
           message.contains("internet") ||
           error is URLError {
            return .networkError
        }

        return .unknown(error.localizedDescription)
    }
}

// MARK: - Delete Account Payload

private struct DeleteAccountPayload: Encodable {
    let appleAuthorizationCode: String?

    enum CodingKeys: String, CodingKey {
        case appleAuthorizationCode = "apple_authorization_code"
    }
}
