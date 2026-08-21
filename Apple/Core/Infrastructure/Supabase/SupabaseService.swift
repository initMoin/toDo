import Foundation
import Supabase

enum SupabaseService {
    static let shared: SupabaseClient = {
        if let configurationIssue = SupabaseConfig.configurationIssue {
            AppLog.error(configurationIssue, logger: AppLog.sync)
        }

        return SupabaseClient(
            supabaseURL: SupabaseConfig.supabaseURL,
            supabaseKey: SupabaseConfig.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: SupabaseConfig.redirectURL,
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()
}

enum SupabaseAccountDeletionError: LocalizedError, Sendable {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "The account deletion response was invalid.")
        case let .requestFailed(statusCode, message):
            if message.isEmpty {
                return String(
                    format: String(localized: "Account deletion failed (%lld)."),
                    statusCode
                )
            }
            return message
        }
    }
}

enum SupabaseAccountDeletionService {
    /// Requests the server-authoritative account deletion flow. The Edge
    /// Function validates this bearer token before deleting any data.
    static func deleteAccount(accessToken: String) async throws {
        var request = URLRequest(
            url: SupabaseConfig.supabaseURL
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent("delete-account")
        )
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAccountDeletionError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SupabaseAccountDeletionError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: deletionErrorMessage(from: data)
            )
        }
    }

    private static func deletionErrorMessage(from data: Data) -> String {
        guard let payload = try? JSONDecoder().decode(
            [String: String].self,
            from: data
        ) else {
            return ""
        }
        return payload["error"] ?? ""
    }
}
