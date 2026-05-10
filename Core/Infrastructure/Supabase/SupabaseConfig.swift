import Foundation

enum SupabaseConfig {
    private enum Key {
        static let url = "SUPABASE_URL"
        static let publishableKey = "SUPABASE_PUBLISHABLE_KEY"
        static let redirectURL = "SUPABASE_REDIRECT_URL"
    }

    static let supabaseURL: URL = requiredURL(for: Key.url)
    static let publishableKey: String = requiredString(for: Key.publishableKey)
    static let redirectURL: URL = requiredURL(for: Key.redirectURL)

    static var callbackScheme: String {
        redirectURL.scheme ?? "todo"
    }

    private static func requiredString(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            fatalError("Missing \(key) in Info.plist")
        }
        return value
    }

    private static func requiredURL(for key: String) -> URL {
        guard let url = URL(string: requiredString(for: key)) else {
            fatalError("Invalid URL for \(key) in Info.plist")
        }
        return url
    }
}
