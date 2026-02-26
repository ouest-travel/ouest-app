import Testing
@testable import Ouest

@Suite("AuthViewModel")
struct AuthViewModelTests {

    @Test("Initial state is loading and not authenticated")
    @MainActor
    func initialState() {
        let vm = AuthViewModel()
        #expect(vm.isLoading == true)
        #expect(vm.isAuthenticated == false)
        #expect(vm.currentUser == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.needsEmailConfirmation == false)
    }

    @Test("restoreSession sets isLoading to false when no session")
    @MainActor
    func restoreSessionNoSession() async throws {
        try #require(Secrets.isConfigured, "Supabase not configured — skipping network test")
        let vm = AuthViewModel()
        await vm.restoreSession()
        #expect(vm.isLoading == false)
    }

    @Test("signIn with empty credentials produces error")
    @MainActor
    func signInEmptyCredentials() async throws {
        try #require(Secrets.isConfigured, "Supabase not configured — skipping network test")
        let vm = AuthViewModel()
        await vm.signIn(email: "", password: "")
        #expect(vm.isLoading == false)
        #expect(vm.isAuthenticated == false)
        #expect(vm.errorMessage != nil)
    }

    @Test("signIn with invalid credentials produces error")
    @MainActor
    func signInInvalidCredentials() async throws {
        try #require(Secrets.isConfigured, "Supabase not configured — skipping network test")
        let vm = AuthViewModel()
        await vm.signIn(email: "notreal@fake.com", password: "wrongpassword123")
        #expect(vm.isLoading == false)
        #expect(vm.isAuthenticated == false)
        #expect(vm.errorMessage != nil)
    }

    @Test("signOut resets state")
    @MainActor
    func signOutResetsState() async throws {
        try #require(Secrets.isConfigured, "Supabase not configured — skipping network test")
        let vm = AuthViewModel()
        // Simulate some state
        vm.isAuthenticated = true
        vm.needsEmailConfirmation = true

        await vm.signOut()
        #expect(vm.isAuthenticated == false)
        #expect(vm.currentUser == nil)
        #expect(vm.needsEmailConfirmation == false)
    }
}
