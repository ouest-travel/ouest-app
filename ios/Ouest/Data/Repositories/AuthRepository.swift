import Foundation
import AuthenticationServices

// MARK: - Local User Model

struct LocalUser: Codable, Equatable {
    let id: String
    let email: String?
    let fullName: String?
    let identityToken: String?
    let authorizationCode: String?
    let createdAt: Date

    var displayName: String {
        fullName ?? email?.components(separatedBy: "@").first ?? "User"
    }
}

// MARK: - Auth Event

enum LocalAuthEvent {
    case signedIn
    case signedOut
    case initialSession
}

// MARK: - Auth Repository Protocol

protocol AuthRepositoryProtocol {
    /// Current authenticated user
    var currentUser: LocalUser? { get }

    /// Check if user is authenticated
    var isAuthenticated: Bool { get }

    /// Handle Apple Sign In credential
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws -> LocalUser

    /// Sign out current user
    func signOut() async throws

    /// Get current session/user
    func getSession() async throws -> LocalUser?

    /// Check credential state with Apple
    func checkCredentialState() async -> Bool
}

// MARK: - Auth Repository Implementation

final class AuthRepository: AuthRepositoryProtocol {
    private let userDefaultsKey = "ouest_current_user"
    private let keychainService = "com.ouest.auth"

    private(set) var currentUser: LocalUser?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    init() {
        // Load saved user on init
        loadSavedUser()
    }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws -> LocalUser {
        let userId = credential.user

        // Get email - only provided on first sign in
        let email = credential.email

        // Get full name - only provided on first sign in
        var fullName: String?
        if let nameComponents = credential.fullName {
            let givenName = nameComponents.givenName ?? ""
            let familyName = nameComponents.familyName ?? ""
            fullName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
            if fullName?.isEmpty == true {
                fullName = nil
            }
        }

        // Get identity token
        var identityToken: String?
        if let tokenData = credential.identityToken {
            identityToken = String(data: tokenData, encoding: .utf8)
        }

        // Get authorization code
        var authorizationCode: String?
        if let codeData = credential.authorizationCode {
            authorizationCode = String(data: codeData, encoding: .utf8)
        }

        // Check if we have an existing user (for re-authentication)
        let existingUser = loadSavedUser()

        // Create user - preserve existing data if this is a re-auth
        let user = LocalUser(
            id: userId,
            email: email ?? existingUser?.email,
            fullName: fullName ?? existingUser?.fullName,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            createdAt: existingUser?.createdAt ?? Date()
        )

        // Save user
        try saveUser(user)
        currentUser = user

        return user
    }

    func signOut() async throws {
        clearSavedUser()
        currentUser = nil
    }

    func getSession() async throws -> LocalUser? {
        return currentUser
    }

    func checkCredentialState() async -> Bool {
        guard let userId = currentUser?.id else { return false }

        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userId) { state, error in
                switch state {
                case .authorized:
                    continuation.resume(returning: true)
                case .revoked, .notFound, .transferred:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Private Storage Methods

    @discardableResult
    private func loadSavedUser() -> LocalUser? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let user = try decoder.decode(LocalUser.self, from: data)
            currentUser = user
            return user
        } catch {
            print("Failed to decode saved user: \(error)")
            return nil
        }
    }

    private func saveUser(_ user: LocalUser) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(user)
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func clearSavedUser() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

// MARK: - Mock Auth Repository

final class MockAuthRepository: AuthRepositoryProtocol {
    var currentUser: LocalUser? = LocalUser(
        id: "demo-user-1",
        email: "demo@ouest.app",
        fullName: "Demo User",
        identityToken: nil,
        authorizationCode: nil,
        createdAt: Date()
    )

    var isAuthenticated: Bool { currentUser != nil }

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws -> LocalUser {
        // In demo mode, just return the demo user
        return currentUser!
    }

    func signOut() async throws {
        // No-op in demo mode
    }

    func getSession() async throws -> LocalUser? {
        return currentUser
    }

    func checkCredentialState() async -> Bool {
        return true
    }
}

// MARK: - Auth Repository Errors

enum AuthRepositoryError: LocalizedError {
    case signInFailed
    case credentialRevoked
    case userNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in with Apple failed. Please try again."
        case .credentialRevoked:
            return "Your Apple ID authorization was revoked. Please sign in again."
        case .userNotFound:
            return "No user found. Please sign in."
        case .saveFailed:
            return "Failed to save user data."
        }
    }
}
