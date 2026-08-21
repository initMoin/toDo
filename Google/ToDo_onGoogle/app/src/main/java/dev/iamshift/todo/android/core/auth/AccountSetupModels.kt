package dev.iamshift.todo.android.core.auth

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
internal data class AndroidProfileResolutionRecord(
    val id: String,
    val username: String? = null,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("account_setup_version") val accountSetupVersion: Int? = null
) {
    val isResolved: Boolean
        get() = !username.isNullOrBlank() && (accountSetupVersion ?: 1) >= 2
}

@Serializable
internal data class AndroidAccountEntitlementRecord(
    @SerialName("entitlement_key") val entitlementKey: String,
    val status: String,
    @SerialName("access_mode") val accessMode: String,
    @SerialName("source_kind") val sourceKind: String,
    @SerialName("source_product_id") val sourceProductId: String? = null
)

@Serializable
internal data class AndroidAccountRoleRecord(
    val role: String
)

@Serializable
internal data class UsernameClaimParameters(
    @SerialName("requested_username") val requestedUsername: String
)

@Serializable
internal data class UsernameClaimResponse(
    @SerialName("account_id") val accountId: String,
    val username: String,
    @SerialName("account_setup_version") val accountSetupVersion: Int
)
