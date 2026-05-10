import Foundation
import Supabase

enum SupabaseService {
    static let shared = SupabaseClient(
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
}
