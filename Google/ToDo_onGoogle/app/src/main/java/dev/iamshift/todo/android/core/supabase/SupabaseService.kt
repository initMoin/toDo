package dev.iamshift.todo.android.core.supabase

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.storage.Storage
import io.ktor.client.engine.okhttp.OkHttp

/** Owns the provider SDK instance; domain and presentation code depend on services instead. */
object SupabaseService {
    val client: SupabaseClient by lazy {
        SupabaseConfig.requireConfigured()

        createSupabaseClient(
            supabaseUrl = SupabaseConfig.url,
            supabaseKey = SupabaseConfig.publishableKey
        ) {
            httpEngine = OkHttp.create()
            install(Auth) {
                scheme = SupabaseConfig.redirectScheme
                host = SupabaseConfig.redirectHost
                flowType = FlowType.PKCE
            }
            install(Postgrest)
            install(Storage)
            install(Realtime)
        }
    }
}
