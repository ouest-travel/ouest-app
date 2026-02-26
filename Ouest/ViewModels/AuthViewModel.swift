import Foundation
import Observation
import Supabase

@MainActor @Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: Profile?
    var errorMessage: String?

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await SupabaseManager.client.auth.session
            isAuthenticated = true
            await fetchProfile(userId: session.user.id)
        } catch {
            isAuthenticated = false
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await SupabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
            isAuthenticated = true
            await fetchProfile(userId: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String, fullName: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await SupabaseManager.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            if response.session != nil {
                isAuthenticated = true
                await fetchProfile(userId: response.user.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        errorMessage = nil
        do {
            try await SupabaseManager.client.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchProfile(userId: UUID) async {
        do {
            let profile: Profile = try await SupabaseManager.client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            currentUser = profile
        } catch {
            // Profile may not exist yet if trigger hasn't fired
            currentUser = nil
        }
    }
}
