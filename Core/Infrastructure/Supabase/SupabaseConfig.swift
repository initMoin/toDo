import Foundation

enum SupabaseConfig {
    private enum Key {
        static let url = "SUPABASE_URL"
        static let publishableKey = "SUPABASE_PUBLISHABLE_KEY"
        static let redirectURL = "SUPABASE_REDIRECT_URL"
    }

    static let supabaseURL: URL = optionalWebURL(for: Key.url) ?? URL(string: "https://localhost.invalid")!
    static let publishableKey: String = optionalString(for: Key.publishableKey) ?? "missing-supabase-publishable-key"
    static let redirectURL: URL = optionalURL(for: Key.redirectURL) ?? URL(string: "todo://auth-callback")!

    static var isConfigured: Bool {
        optionalWebURL(for: Key.url) != nil &&
        optionalString(for: Key.publishableKey) != nil &&
        optionalURL(for: Key.redirectURL) != nil
    }

    static var configurationIssue: String? {
        if optionalWebURL(for: Key.url) == nil {
            return "Missing or invalid \(Key.url) in Info.plist"
        }
        if optionalString(for: Key.publishableKey) == nil {
            return "Missing \(Key.publishableKey) in Info.plist"
        }
        if optionalURL(for: Key.redirectURL) == nil {
            return "Missing or invalid \(Key.redirectURL) in Info.plist"
        }
        return nil
    }

    static var callbackScheme: String {
        redirectURL.scheme ?? "todo"
    }

    private static func optionalString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private static func optionalURL(for key: String) -> URL? {
        optionalString(for: key).flatMap(URL.init(string:))
    }

    private static func optionalWebURL(for key: String) -> URL? {
        guard let url = optionalURL(for: key),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            return nil
        }

        return url
    }
}
