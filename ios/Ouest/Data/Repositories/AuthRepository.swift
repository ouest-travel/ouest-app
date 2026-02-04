import Foundation
import Supabase

// MARK: - Auth Repository Protocol

protocol AuthRepositoryProtocol {
    /// Current authenticated user
    var currentUser: User? { get async }

    /// Sign up with email and password
    func signUp(email: String, password: String, displayName: String) async throws -> User

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> Session

    /// Sign out current user
    func signOut() async throws

    /// Get current session
    func getSession() async throws -> Session?

    /// Listen to auth state changes
    func observeAuthState(onChange: @escaping (AuthChangeEvent, Session?) -> Void) -> any Cancellable
}

// MARK: - Auth Repository Implementation

final class AuthRepository: AuthRepositoryProtocol {
    private let client: SupabaseClient
    private let profileRepository: ProfileRepositoryProtocol

    init(
        client: SupabaseClient = SupabaseService.shared.client,
        profileRepository: ProfileRepositoryProtocol? = nil
    ) {
        self.client = client
        self.profileRepository = profileRepository ?? ProfileRepository(client: client)
    }

    var currentUser: User? {
        get async {
            try? await client.auth.session.user
        }
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )

        guard let user = response.user else {
            throw AuthRepositoryError.signUpFailed
        }

        // Create profile for new user
        try await createProfile(userId: user.id.uuidString, email: email, displayName: displayName)

        return user
    }

    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        return session
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getSession() async throws -> Session? {
        return try? await client.auth.session
    }

    func observeAuthState(onChange: @escaping (AuthChangeEvent, Session?) -> Void) -> any Cancellable {
        let task = Task {
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    onChange(event, session)
                }
            }
        }

        return SubscriptionToken {
            task.cancel()
        }
    }

    // MARK: - Private Helpers

    private func createProfile(userId: String, email: String, displayName: String) async throws {
        let handle = generateHandle(from: displayName, email: email)

        let profileData: [String: AnyJSON] = [
            "id": .string(userId),
            "email": .string(email),
            "display_name": .string(displayName),
            "handle": .string(handle)
        ]

        try await client
            .from(Tables.profiles)
            .insert(profileData)
            .execute()
    }

    private func generateHandle(from displayName: String, email: String) -> String {
        let base = displayName.isEmpty
            ? email.components(separatedBy: "@").first ?? "user"
            : displayName

        let handle = base
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        let suffix = String(Int.random(in: 100...999))
        return "\(handle)\(suffix)"
    }
}

// MARK: - Mock Auth Repository

final class MockAuthRepository: AuthRepositoryProtocol {
    var currentUser: User? {
        get async { nil }
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        try await Task.sleep(nanoseconds: 500_000_000)
        throw AuthRepositoryError.signUpFailed // Demo mode doesn't support real auth
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await Task.sleep(nanoseconds: 500_000_000)
        throw AuthRepositoryError.signInFailed
    }

    func signOut() async throws {
        // No-op in demo mode
    }

    func getSession() async throws -> Session? {
        return nil
    }

    func observeAuthState(onChange: @escaping (AuthChangeEvent, Session?) -> Void) -> any Cancellable {
        return SubscriptionToken { }
    }
}

// MARK: - Auth Repository Errors

enum AuthRepositoryError: LocalizedError {
    case signUpFailed
    case signInFailed
    case sessionNotFound
    case profileCreationFailed

    var errorDescription: String? {
        switch self {
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .signInFailed:
            return "Invalid email or password."
        case .sessionNotFound:
            return "No active session. Please sign in."
        case .profileCreationFailed:
            return "Failed to create profile."
        }
    }
}
