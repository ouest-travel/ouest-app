import Foundation
import Observation

@MainActor @Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: Profile?
    var errorMessage: String?
    var needsEmailConfirmation = false

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await AuthService.restoreSession()
            isAuthenticated = true
            await loadProfile(userId: session.user.id)
        } catch {
            isAuthenticated = false
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await AuthService.signIn(email: email, password: password)
            isAuthenticated = true
            await loadProfile(userId: session.user.id)
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String, fullName: String) async {
        errorMessage = nil
        needsEmailConfirmation = false
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await AuthService.signUp(
                email: email,
                password: password,
                fullName: fullName
            )

            if let session {
                // Logged in immediately (email confirmation disabled)
                isAuthenticated = true
                await loadProfile(userId: session.user.id)
            } else {
                // Email confirmation required
                needsEmailConfirmation = true
            }
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await AuthService.signOut()
            isAuthenticated = false
            currentUser = nil
            needsEmailConfirmation = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            try await AuthService.resetPassword(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadProfile(userId: UUID) async {
        do {
            currentUser = try await AuthService.fetchProfile(userId: userId)
        } catch {
            // Profile may not exist yet if trigger hasn't fired
            currentUser = nil
        }
    }

    // MARK: - Dev Sign-In (DEBUG only)

    #if DEBUG
    /// One-tap dev sign-in using a test Supabase account.
    /// If the test account doesn't exist yet, creates it first.
    func devSignIn() async {
        let email = "dev@ouest.app"
        let password = "devpassword123"
        let fullName = "Dev User"

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // Try signing in first
            let session = try await AuthService.signIn(email: email, password: password)
            isAuthenticated = true
            await loadProfile(userId: session.user.id)
        } catch {
            // Account likely doesn't exist — create it, then sign in
            do {
                _ = try await AuthService.signUp(email: email, password: password, fullName: fullName)
                let session = try await AuthService.signIn(email: email, password: password)
                isAuthenticated = true
                await loadProfile(userId: session.user.id)
            } catch {
                errorMessage = "Dev sign-in failed: \(error.localizedDescription)"
            }
        }
    }
    #endif
}
