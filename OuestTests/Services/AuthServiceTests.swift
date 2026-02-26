import Testing
@testable import Ouest

@Suite("AuthError")
struct AuthErrorTests {

    @Test("AuthError provides user-friendly messages")
    func errorMessages() {
        #expect(AuthError.invalidCredentials.errorDescription != nil)
        #expect(AuthError.emailAlreadyExists.errorDescription != nil)
        #expect(AuthError.weakPassword.errorDescription != nil)
        #expect(AuthError.networkError.errorDescription != nil)
        #expect(AuthError.emailNotConfirmed.errorDescription != nil)
        #expect(AuthError.unknown("Custom").errorDescription == "Custom")
    }

    @Test("invalidCredentials message is user-friendly")
    func invalidCredentialsMessage() {
        let message = AuthError.invalidCredentials.errorDescription!
        #expect(message.contains("Invalid"))
        #expect(!message.contains("401")) // Should not expose HTTP codes
    }

    @Test("networkError message mentions connection")
    func networkErrorMessage() {
        let message = AuthError.networkError.errorDescription!
        #expect(message.contains("connect") || message.contains("internet"))
    }

    @Test("unknown error passes through message")
    func unknownErrorMessage() {
        let custom = "Something specific went wrong"
        let error = AuthError.unknown(custom)
        #expect(error.errorDescription == custom)
    }
}
