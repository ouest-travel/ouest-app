import Foundation
import SwiftUI
import Supabase

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
    @Published private(set) var profile: Profile?
    @Published private(set) var error: String?
    @Published var isLoading = false

    // MARK: - Dependencies

    private let authRepository: any AuthRepositoryProtocol
    private let profileRepository: any ProfileRepositoryProtocol
    private var authSubscription: (any Cancellable)?

    // MARK: - Computed Properties

    var isAuthenticated: Bool { state.isAuthenticated }
    var currentUserId: String? { state.userId }

    // MARK: - Initialization

    init(
        authRepository: any AuthRepositoryProtocol,
        profileRepository: any ProfileRepositoryProtocol
    ) {
        self.authRepository = authRepository
        self.profileRepository = profileRepository

        Task {
            await checkSession()
            observeAuthState()
        }
    }

    // MARK: - Session Management

    func checkSession() async {
        state = .loading

        do {
            if let session = try await authRepository.getSession() {
                state = .authenticated(userId: session.user.id.uuidString)
                await loadProfile()
            } else {
                state = .unauthenticated
            }
        } catch {
            state = .unauthenticated
        }
    }

    private func observeAuthState() {
        authSubscription = authRepository.observeAuthState { [weak self] event, session in
            Task { @MainActor in
                guard let self = self else { return }

                switch event {
                case .signedIn:
                    if let session = session {
                        self.state = .authenticated(userId: session.user.id.uuidString)
                        await self.loadProfile()
                    }
                case .signedOut:
                    self.state = .unauthenticated
                    self.profile = nil
                default:
                    break
                }
            }
        }
    }

    // MARK: - Authentication Actions

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        error = nil

        do {
            let user = try await authRepository.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            state = .authenticated(userId: user.id.uuidString)
            await loadProfile()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let session = try await authRepository.signIn(email: email, password: password)
            state = .authenticated(userId: session.user.id.uuidString)
            await loadProfile()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() async {
        do {
            try await authRepository.signOut()
            state = .unauthenticated
            profile = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Profile

    private func loadProfile() async {
        guard let userId = currentUserId else { return }

        do {
            profile = try await profileRepository.getProfile(userId: userId)
        } catch {
            print("Failed to load profile: \(error)")
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
