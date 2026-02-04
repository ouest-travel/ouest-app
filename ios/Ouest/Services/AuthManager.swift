import Foundation
import AuthenticationServices

/// Manages authentication state and operations using Sign in with Apple
@MainActor
class AuthManager: ObservableObject {
    @Published var localUser: LocalUser?
    @Published var profile: Profile?
    @Published var isLoading = true
    @Published var error: Error?

    var isAuthenticated: Bool {
        localUser != nil
    }

    private let authRepository: AuthRepository
    private let profileRepository: ProfileRepository

    init() {
        self.authRepository = AuthRepository()
        self.profileRepository = ProfileRepository()

        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let user = try await authRepository.getSession() {
                // Verify credential is still valid with Apple
                let isValid = await authRepository.checkCredentialState()

                if isValid {
                    self.localUser = user
                    await loadProfile()
                } else {
                    // Credential revoked, sign out
                    try await authRepository.signOut()
                    self.localUser = nil
                    self.profile = nil
                }
            }
        } catch {
            self.localUser = nil
            self.profile = nil
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let user = try await authRepository.handleAppleSignIn(credential: credential)
        self.localUser = user

        // Create or load profile
        await loadOrCreateProfile()
    }

    func signOut() async {
        do {
            try await authRepository.signOut()
            self.localUser = nil
            self.profile = nil
        } catch {
            print("Sign out error: \(error)")
        }
    }

    // MARK: - Profile

    private func loadProfile() async {
        guard let userId = localUser?.id else { return }

        do {
            self.profile = try await profileRepository.getProfile(userId: userId)
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    private func loadOrCreateProfile() async {
        guard let user = localUser else { return }

        do {
            // Try to load existing profile
            if let existingProfile = try await profileRepository.getProfile(userId: user.id) {
                self.profile = existingProfile
            } else {
                // Create new profile
                self.profile = try await profileRepository.createProfile(
                    userId: user.id,
                    email: user.email ?? "\(user.id)@privaterelay.appleid.com",
                    displayName: user.displayName
                )
            }
        } catch {
            print("Failed to load/create profile: \(error)")
            // Create a local profile as fallback
            self.profile = Profile(
                id: user.id,
                email: user.email ?? "",
                displayName: user.displayName,
                handle: nil,
                avatarUrl: nil,
                createdAt: user.createdAt
            )
        }
    }

    func updateProfile(displayName: String?, handle: String?, avatarUrl: String?) async throws {
        guard let userId = localUser?.id else { return }

        self.profile = try await profileRepository.updateProfile(
            userId: userId,
            displayName: displayName,
            handle: handle,
            avatarUrl: avatarUrl
        )
    }
}
