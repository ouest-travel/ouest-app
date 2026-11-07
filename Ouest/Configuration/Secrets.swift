import Foundation

enum Secrets {

    /// Resolve the app bundle — in test context, Bundle.main may point to the
    /// test runner, so we fall back to looking up the app bundle by identifier.
    private static var appBundle: Bundle {
        if let app = Bundle(identifier: "com.ouest.app") {
            return app
        }
        return .main
    }

    /// Whether Supabase configuration is available (false in test-only contexts).
    static var isConfigured: Bool {
        guard let url = appBundle.infoDictionary?["SUPABASE_URL"] as? String,
              !url.isEmpty,
              !url.hasPrefix("$(") else {
            return false
        }
        guard let key = appBundle.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            return false
        }
        return true
    }

    static var supabaseURL: String {
        guard let url = appBundle.infoDictionary?["SUPABASE_URL"] as? String,
              !url.isEmpty,
              !url.hasPrefix("$(") else {
            fatalError("SUPABASE_URL not configured. Set it in your .xcconfig file.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = appBundle.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("SUPABASE_ANON_KEY not configured. Set it in your .xcconfig file.")
        }
        return key
    }

    /// RapidAPI key for Travel Buddy Visa Requirements API.
    static var rapidAPIKey: String {
        guard let key = appBundle.infoDictionary?["RAPIDAPI_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("RAPIDAPI_KEY not configured. Set it in your .xcconfig file.")
        }
        return key
    }

    #if DEBUG
    /// Dev sign-in account — DEBUG builds only. Set DEV_SIGNIN_EMAIL and
    /// DEV_SIGNIN_PASSWORD in Debug.xcconfig (never committed). Returns nil
    /// when either is missing, so dev sign-in reports it instead of crashing.
    static var devSignInCredentials: (email: String, password: String)? {
        guard let email = appBundle.infoDictionary?["DEV_SIGNIN_EMAIL"] as? String,
              let password = appBundle.infoDictionary?["DEV_SIGNIN_PASSWORD"] as? String,
              !email.isEmpty, !password.isEmpty,
              !email.hasPrefix("$("), !password.hasPrefix("$(") else {
            return nil
        }
        return (email, password)
    }

    /// Service role key for admin operations — DEBUG builds only.
    /// Used exclusively by dev sign-in to create a pre-confirmed test user.
    static var supabaseServiceRoleKey: String {
        guard let key = appBundle.infoDictionary?["SUPABASE_SERVICE_ROLE_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("SUPABASE_SERVICE_ROLE_KEY not configured. Set it in Debug.xcconfig.")
        }
        return key
    }
    #endif
}
