import Foundation
import Supabase

/// Manages authentication state and operations
@MainActor
class AuthManager: ObservableObject {
    @Published var user: User?
    @Published var session: Session?
    @Published var profile: Profile?
    @Published var isLoading = true
    @Published var error: AuthError?

    var isAuthenticated: Bool {
        session != nil
    }

    private var authStateTask: Task<Void, Never>?

    init() {
        Task {
            await checkSession()
            await listenToAuthChanges()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Session Management

    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await SupabaseService.shared.auth.session
            self.session = session
            self.user = session.user

            // Load profile
            await loadProfile()
        } catch {
            self.session = nil
            self.user = nil
            self.profile = nil
        }
    }

    func listenToAuthChanges() async {
        authStateTask = Task {
            for await (event, session) in SupabaseService.shared.auth.authStateChanges {
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    self.session = session
                    self.user = session?.user

                    switch event {
                    case .signedIn:
                        Task {
                            await self.loadProfile()
                        }
                    case .signedOut:
                        self.profile = nil
                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Authentication

    func signUp(email: String, password: String, displayName: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response = try await SupabaseService.shared.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )

            self.session = response.session
            self.user = response.user

            // Create profile
            if let userId = response.user?.id.uuidString {
                try await createProfile(
                    userId: userId,
                    email: email,
                    displayName: displayName
                )
            }
        } catch let authError as AuthError {
            self.error = authError
            throw authError
        }
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let session = try await SupabaseService.shared.auth.signIn(
                email: email,
                password: password
            )

            self.session = session
            self.user = session.user
            await loadProfile()
        } catch let authError as AuthError {
            self.error = authError
            throw authError
        }
    }

    func signOut() async {
        do {
            try await SupabaseService.shared.auth.signOut()
            self.session = nil
            self.user = nil
            self.profile = nil
        } catch {
            print("Sign out error: \(error)")
        }
    }

    // MARK: - Profile

    private func loadProfile() async {
        guard let userId = user?.id.uuidString else { return }

        do {
            let profile: Profile = try await SupabaseService.shared
                .from(Tables.profiles)
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.profile = profile
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    private func createProfile(userId: String, email: String, displayName: String) async throws {
        let handle = generateHandle(from: displayName, email: email)

        let profileData: [String: AnyJSON] = [
            "id": .string(userId),
            "email": .string(email),
            "display_name": .string(displayName),
            "handle": .string(handle)
        ]

        try await SupabaseService.shared
            .from(Tables.profiles)
            .insert(profileData)
            .execute()

        await loadProfile()
    }

    func updateProfile(displayName: String?, handle: String?, avatarUrl: String?) async throws {
        guard let userId = user?.id.uuidString else { return }

        var updates: [String: AnyJSON] = [:]

        if let displayName = displayName {
            updates["display_name"] = .string(displayName)
        }
        if let handle = handle {
            updates["handle"] = .string(handle)
        }
        if let avatarUrl = avatarUrl {
            updates["avatar_url"] = .string(avatarUrl)
        }

        guard !updates.isEmpty else { return }

        try await SupabaseService.shared
            .from(Tables.profiles)
            .update(updates)
            .eq("id", value: userId)
            .execute()

        await loadProfile()
    }

    // MARK: - Helpers

    private func generateHandle(from displayName: String, email: String) -> String {
        let base = displayName.isEmpty
            ? email.components(separatedBy: "@").first ?? "user"
            : displayName

        // Convert to lowercase, remove spaces and special characters
        let handle = base
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        // Add random suffix for uniqueness
        let suffix = String(Int.random(in: 100...999))
        return "\(handle)\(suffix)"
    }
}

// MARK: - Error Extension

extension AuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found. Please sign in again."
        default:
            return "An authentication error occurred."
        }
    }
}
