package dev.iamshift.todo.android.core.auth

import android.content.Context
import java.util.UUID

/**
 * Stable installation identity used for mutation provenance and idempotency.
 * It is deliberately unrelated to an account identity and survives sign-out.
 */
class DeviceIdentityStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    val deviceId: UUID
        get() = synchronized(preferences) {
            preferences.getString(KEY_DEVICE_ID, null)
                ?.let { stored -> runCatching { UUID.fromString(stored) }.getOrNull() }
                ?: UUID.randomUUID().also { generated ->
                    check(preferences.edit().putString(KEY_DEVICE_ID, generated.toString()).commit()) {
                        "Unable to persist the Android installation identity"
                    }
                }
        }

    private companion object {
        const val PREFERENCES_NAME = "todo_android_identity"
        const val KEY_DEVICE_ID = "device_id"
    }
}
