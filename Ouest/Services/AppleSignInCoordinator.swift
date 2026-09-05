import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates the native Apple Sign In flow using ASAuthorizationController.
/// Returns the identity token and nonce needed for Supabase auth.
@MainActor
final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    /// The raw (unhashed) nonce for the current request — Supabase needs this to verify the token.
    private var currentNonce = ""

    struct AppleSignInResult: Sendable {
        let identityToken: String
        let nonce: String
        let fullName: String?
        let email: String?
    }

    /// Starts the Apple Sign In flow and returns the result.
    func signIn() async throws -> AppleSignInResult {
        let rawNonce = Self.randomNonceString()
        currentNonce = rawNonce
        let hashedNonce = Self.sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
                continuation = nil
                return
            }

            // Build full name from components (Apple only sends this on first sign-in)
            var fullName: String?
            if let nameComponents = credential.fullName {
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: nameComponents)
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    fullName = name
                }
            }

            let result = AppleSignInResult(
                identityToken: identityToken,
                nonce: currentNonce,
                fullName: fullName,
                email: credential.email
            )

            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let authError = error as? ASAuthorizationError,
                authError.code == .canceled
            {
                continuation?.resume(throwing: AppleSignInError.cancelled)
            } else {
                continuation?.resume(throwing: AppleSignInError.failed(error.localizedDescription))
            }
            continuation = nil
        }
    }

    // MARK: - Presentation Context

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = scene.windows.first
            else {
                return ASPresentationAnchor()
            }
            return window
        }
    }

    // MARK: - Nonce Helpers

    /// Generate a random nonce string for Apple Sign In.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 hash of a string, returned as a hex string.
    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple Sign In Errors

enum AppleSignInError: LocalizedError {
    case missingIdentityToken
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            "Unable to retrieve identity token from Apple."
        case .cancelled:
            nil  // Don't show error for user-initiated cancellation
        case .failed(let message):
            "Apple Sign In failed: \(message)"
        }
    }
}
