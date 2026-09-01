import AuthenticationServices
import Foundation
import Observation

@MainActor @Observable
final class AuthViewModel {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: Profile?
    var errorMessage: String?
    var needsEmailConfirmation = false
    var needsOnboarding = false
    /// True when the current session was established via a password-recovery
    /// callback — the user must set a new password before doing anything else.
    /// ContentView routes to NewPasswordView while this is true.
    var isPasswordRecovery = false

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

    /// Complete a signUp / magic-link / password-recovery flow by handing the
    /// callback URL to Supabase. The client parses tokens (PKCE code or
    /// implicit access token) off the URL, persists the session in Keychain,
    /// and returns it. On success we flip UI state so ContentView transitions
    /// from LoginView to onboarding / main / new-password as appropriate.
    func handleAuthCallback(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        // Supabase encodes the flow type on the callback URL — `type=recovery`
        // for password-reset links, `type=signup` for email confirmations.
        // Check BEFORE consuming the URL so we can pick the right destination
        // regardless of which branch (implicit fragment vs PKCE query) it
        // arrived on.
        let isRecovery = Self.callbackType(from: url) == "recovery"

        do {
            let session = try await SupabaseManager.client.auth.session(from: url)
            isAuthenticated = true
            needsEmailConfirmation = false

            if isRecovery {
                // Route to NewPasswordView. Do NOT load profile / trigger
                // onboarding — this session's only job is to accept a new
                // password, then the user re-enters the normal flow.
                isPasswordRecovery = true
                return
            }

            await loadProfile(userId: session.user.id)
            // A freshly-confirmed account needs onboarding. If loadProfile
            // discovers the user already has a handle (rare here — this path
            // is a fresh confirmation — but future-proof for magic-link
            // sign-ins on existing accounts), don't force onboarding.
            if currentUser?.handle == nil {
                needsOnboarding = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Extract Supabase's `type` param from a callback URL. It lives in the
    /// query string on PKCE flows and in the URL fragment on implicit flows —
    /// check both so recovery detection works regardless of project config.
    private static func callbackType(from url: URL) -> String? {
        if let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "type" })?.value, !q.isEmpty {
            return q
        }
        if let fragment = url.fragment {
            var comps = URLComponents()
            comps.query = fragment
            return comps.queryItems?.first(where: { $0.name == "type" })?.value
        }
        return nil
    }

    /// Finalize a password-recovery flow by writing the new password and
    /// returning the user to the normal authenticated state. On success,
    /// clears `isPasswordRecovery` so ContentView routes back to Main / Onboarding.
    func updatePassword(newPassword: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthService.updatePassword(newPassword)
            isPasswordRecovery = false
            // Load the profile now that we're past recovery so Main renders
            // with the user's data on first frame.
            if let userId = try? await SupabaseManager.client.auth.session.user.id {
                await loadProfile(userId: userId)
            }
        } catch {
            errorMessage = error.localizedDescription
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
                needsOnboarding = true
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

    // MARK: - Apple Sign In

    private let appleSignInCoordinator = AppleSignInCoordinator()

    func signInWithApple() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Present native Apple Sign In sheet and get credentials
            let appleResult = try await appleSignInCoordinator.signIn()

            // 2. Exchange Apple identity token with Supabase
            let session = try await AuthService.signInWithApple(
                idToken: appleResult.identityToken,
                nonce: appleResult.nonce
            )

            isAuthenticated = true
            await loadProfile(userId: session.user.id)

            // 3. Update profile with Apple-provided name if available and profile name is empty
            if let fullName = appleResult.fullName,
               currentUser?.fullName == nil || currentUser?.fullName?.isEmpty == true
            {
                let payload = UpdateProfilePayload(fullName: fullName)
                try? await updateProfile(payload)
            }

            // 4. Show onboarding for first-time Apple sign-in users
            if currentUser?.handle == nil && currentUser?.travelInterests == nil {
                needsOnboarding = true
            }
        } catch let error as AppleSignInError {
            // .cancelled has nil errorDescription — only show real errors
            if let message = error.errorDescription {
                errorMessage = message
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
            isPasswordRecovery = false
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

    // MARK: - Onboarding

    func completeOnboarding() {
        needsOnboarding = false
    }

    // MARK: - Profile Management

    /// Update the current user's profile fields and refresh the cached profile
    func updateProfile(_ payload: UpdateProfilePayload) async throws {
        guard let userId = currentUser?.id else { return }
        let updated: Profile = try await SupabaseManager.client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
        currentUser = updated
    }

    /// Refresh the cached profile from the server
    func refreshProfile() async {
        guard let userId = currentUser?.id else { return }
        await loadProfile(userId: userId)
    }

    private func loadProfile(userId: UUID) async {
        // Retry a few times — the DB trigger that creates the profile row
        // may not have fired yet for brand-new signups.
        for attempt in 0..<4 {
            do {
                currentUser = try await AuthService.fetchProfile(userId: userId)
                return
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        currentUser = nil
    }

    // MARK: - Dev Sign-In (DEBUG only)

    #if DEBUG
    /// One-tap dev sign-in using a test Supabase account.
    /// Creates the account via Admin API (with email pre-confirmed) if it doesn't exist.
    func devSignIn() async {
        let email = "dev@ouest.app"
        let password = "devpassword123"
        let fullName = "Dev User"

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // Try signing in first — works if account already exists and is confirmed
            let session = try await AuthService.signIn(email: email, password: password)
            isAuthenticated = true
            await loadProfile(userId: session.user.id)
        } catch {
            // Account doesn't exist or email not confirmed — create via Admin API
            do {
                try await createConfirmedDevUser(email: email, password: password, fullName: fullName)
                let session = try await AuthService.signIn(email: email, password: password)
                isAuthenticated = true
                await loadProfile(userId: session.user.id)
            } catch {
                errorMessage = "Dev sign-in failed: \(error.localizedDescription)"
            }
        }
    }

    /// Creates a dev user via the Supabase Admin API with email pre-confirmed.
    /// Uses the service role key (DEBUG only) to bypass email confirmation.
    private func createConfirmedDevUser(email: String, password: String, fullName: String) async throws {
        let url = URL(string: "\(Secrets.supabaseURL)/auth/v1/admin/users")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseServiceRoleKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseServiceRoleKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "email_confirm": true,
            "user_metadata": ["full_name": fullName]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // 200 = created, 422 = user already exists (may need email confirmed)
        if httpResponse.statusCode == 422 {
            // User exists but email may not be confirmed — confirm via admin update
            try await confirmExistingDevUser(email: email)
            return
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "DevSignIn",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Admin API (\(httpResponse.statusCode)): \(errorBody)"]
            )
        }
    }

    /// Confirms an existing dev user's email via the Admin API.
    private func confirmExistingDevUser(email: String) async throws {
        // List users to find the dev user's ID
        let listURL = URL(string: "\(Secrets.supabaseURL)/auth/v1/admin/users")!

        var listRequest = URLRequest(url: listURL)
        listRequest.httpMethod = "GET"
        listRequest.setValue("Bearer \(Secrets.supabaseServiceRoleKey)", forHTTPHeaderField: "Authorization")
        listRequest.setValue(Secrets.supabaseServiceRoleKey, forHTTPHeaderField: "apikey")

        let (listData, _) = try await URLSession.shared.data(for: listRequest)
        let listResponse = try JSONSerialization.jsonObject(with: listData) as? [String: Any]
        guard let users = listResponse?["users"] as? [[String: Any]],
              let devUser = users.first(where: { ($0["email"] as? String) == email }),
              let userId = devUser["id"] as? String else {
            return
        }

        // Update user to confirm their email
        let updateURL = URL(string: "\(Secrets.supabaseURL)/auth/v1/admin/users/\(userId)")!

        var updateRequest = URLRequest(url: updateURL)
        updateRequest.httpMethod = "PUT"
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.setValue("Bearer \(Secrets.supabaseServiceRoleKey)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue(Secrets.supabaseServiceRoleKey, forHTTPHeaderField: "apikey")

        let updateBody: [String: Any] = ["email_confirm": true]
        updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateBody)

        let (_, updateResponse) = try await URLSession.shared.data(for: updateRequest)
        guard let httpResponse = updateResponse as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "DevSignIn",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to confirm dev user email"]
            )
        }
    }
    #endif
}
