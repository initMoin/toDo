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
