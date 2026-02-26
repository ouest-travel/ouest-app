import Foundation

enum Secrets {
    static var supabaseURL: String {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty else {
            fatalError("SUPABASE_URL not configured. Set it in your .xcconfig file.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured. Set it in your .xcconfig file.")
        }
        return key
    }
}
