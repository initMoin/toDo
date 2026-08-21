package dev.iamshift.todo.android.core.supabase

import dev.iamshift.todo.android.BuildConfig

/** Build-time client configuration. The publishable key is intentionally client-safe. */
object SupabaseConfig {
    const val redirectScheme: String = "todo"
    const val redirectHost: String = "auth-callback"
    const val redirectUri: String = "$redirectScheme://$redirectHost"

    val url: String = BuildConfig.SUPABASE_URL.trim()
    val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY.trim()

    val isConfigured: Boolean
        get() = url.startsWith("https://") &&
            url.length > "https://".length &&
            publishableKey.isNotEmpty()

    val configurationIssue: String?
        get() = when {
            !url.startsWith("https://") -> "Supabase URL is missing or is not HTTPS."
            publishableKey.isEmpty() -> "Supabase publishable key is missing."
            else -> null
        }

    fun requireConfigured() {
        check(isConfigured) { configurationIssue ?: "Supabase is not configured." }
    }
}
