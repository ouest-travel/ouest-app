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
                data: ["full_name": .string(fullName)]
            )
            return response.session
        } catch {
            throw mapError(error)
        }
    }

    /// Sign out the current user
    static func signOut() async throws {
        try await SupabaseManager.client.auth.signOut()
    }

    /// Restore an existing session from Keychain
    static func restoreSession() async throws -> Session {
        try await SupabaseManager.client.auth.session
    }

    /// Send a password reset email
    static func resetPassword(email: String) async throws {
        try await SupabaseManager.client.auth.resetPasswordForEmail(email)
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
