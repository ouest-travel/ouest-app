import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case authenticated(userId: String)
    case unauthenticated

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var userId: String? {
        if case .authenticated(let id) = self { return id }
        return nil
    }
}

// MARK: - Auth ViewModel

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: AuthState = .loading
    @Published private(set) var localUser: LocalUser?
    @Published private(set) var profile: Profile?
    @Published private(set) var error: String?
    @Published var isLoading = false

    // MARK: - Dependencies

    private let authRepository: any AuthRepositoryProtocol
    private let profileRepository: any ProfileRepositoryProtocol

    // MARK: - Computed Properties

    var isAuthenticated: Bool { state.isAuthenticated }
    var currentUserId: String? { state.userId }
    var currentUserDisplayName: String? { localUser?.displayName }
    var currentUserEmail: String? { localUser?.email }

    // MARK: - Initialization

    init(
        authRepository: any AuthRepositoryProtocol,
        profileRepository: any ProfileRepositoryProtocol
    ) {
        self.authRepository = authRepository
        self.profileRepository = profileRepository

        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        state = .loading

        do {
            if let user = try await authRepository.getSession() {
                // Verify credential is still valid with Apple
                let isValid = await authRepository.checkCredentialState()

                if isValid {
                    localUser = user
                    state = .authenticated(userId: user.id)
                    await loadOrCreateProfile()
                } else {
                    // Credential revoked, sign out
                    try await authRepository.signOut()
                    state = .unauthenticated
                }
            } else {
                state = .unauthenticated
            }
        } catch {
            state = .unauthenticated
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.error = "Invalid credential type"
                return
            }

            do {
                let user = try await authRepository.handleAppleSignIn(credential: appleIDCredential)
                localUser = user
                state = .authenticated(userId: user.id)
                await loadOrCreateProfile()
            } catch {
                self.error = error.localizedDescription
            }

        case .failure(let error):
            // Don't show error for user cancellation
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            self.error = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await authRepository.signOut()
            state = .unauthenticated
            localUser = nil
            profile = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Profile Management

    private func loadOrCreateProfile() async {
        guard let userId = currentUserId else { return }

        do {
            // Try to load existing profile
            profile = try await profileRepository.getProfile(userId: userId)
        } catch {
            // Profile doesn't exist, create one from Apple Sign In data
            if let user = localUser {
                do {
                    profile = try await profileRepository.createProfile(
                        userId: user.id,
                        email: user.email ?? "\(user.id)@privaterelay.appleid.com",
                        displayName: user.displayName
                    )
                } catch {
                    print("Failed to create profile: \(error)")
                    // Create a local profile as fallback
                    profile = Profile(
                        id: user.id,
                        email: user.email ?? "",
                        displayName: user.displayName,
                        handle: nil,
                        avatarUrl: nil,
                        createdAt: user.createdAt
                    )
                }
            }
        }
    }

    func updateProfile(displayName: String?, handle: String?, avatarUrl: String?) async {
        guard let userId = currentUserId else { return }

        isLoading = true
        error = nil

        do {
            profile = try await profileRepository.updateProfile(
                userId: userId,
                displayName: displayName,
                handle: handle,
                avatarUrl: avatarUrl
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Error Handling

    func clearError() {
        error = nil
    }
}

// MARK: - Demo Mode Auth ViewModel

@MainActor
final class DemoAuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState = .authenticated(userId: "demo-user-1")
    @Published private(set) var profile: Profile? = DemoModeManager.demoProfile
    @Published private(set) var error: String?
    @Published var isLoading = false

    var isAuthenticated: Bool { true }
    var currentUserId: String? { "demo-user-1" }

    func signOut() async {
        // No-op in demo mode, but could toggle to show sign-in screen
    }
}

// MARK: - Apple Sign In Button Coordinator

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var onComplete: ((Result<ASAuthorization, Error>) -> Void)?

    func startSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onComplete?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onComplete?(.failure(error))
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
