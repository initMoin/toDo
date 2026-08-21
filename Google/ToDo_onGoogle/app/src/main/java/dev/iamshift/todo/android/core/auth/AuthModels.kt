package dev.iamshift.todo.android.core.auth

import dev.iamshift.todo.android.core.sync.SyncScope
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class AccountAuthenticationIntent {
    CREATE_ACCOUNT,
    SIGN_IN,
    RESTORE_SESSION
}

enum class AccountResolutionState {
    SIGNED_OUT,
    RESOLVING,
    NEEDS_USERNAME,
    MIGRATION_REQUIRED,
    ACCOUNT_MISMATCH,
    RESOLVED
}

/** Provider-neutral account identity. The same UUID scopes Supabase and Firebase data. */
data class AuthenticatedAccount(
    val userId: UUID,
    val email: String? = null,
    val username: String? = null,
    val displayName: String? = null,
    val avatarUrl: String? = null,
    val linkedProviders: Set<String> = emptySet(),
    val accountRole: String? = null,
    val entitlements: AccountEntitlements = AccountEntitlements.empty,
    val accountSetupVersion: Int? = null,
    val resolutionState: AccountResolutionState = AccountResolutionState.RESOLVING,
    val resolutionMessage: String? = null
) {
    val isResolved: Boolean
        get() = resolutionState == AccountResolutionState.RESOLVED

    val hasToDoPlusAccess: Boolean
        get() = entitlements.hasFullPlus || entitlements.isPioneer

    val membershipLabel: String
        get() = entitlements.membershipLabel
}

/** The account-scoped commerce records returned by the shared entitlement view. */
data class AccountEntitlementRecord(
    val entitlementKey: String,
    val status: String,
    val accessMode: String,
    val sourceKind: String,
    val sourceProductId: String? = null
)

/**
 * Capability projection used by Android UI and future feature gates.
 *
 * This deliberately mirrors Apple's server-authoritative rules instead of
 * inferring access from the presence of a local purchase or provider login.
 */
data class AccountEntitlements(
    val records: List<AccountEntitlementRecord> = emptyList()
) {
    companion object {
        val empty = AccountEntitlements()

        private const val ENTITLEMENT_PLUS = "todo_plus"
        private const val ENTITLEMENT_FOUNDING_SUPPORTER = "founding_supporter"
        private const val ENTITLEMENT_LEGACY_31 = "legacy_3_1"
        private const val SOURCE_GRANDFATHERING = "grandfathering"
        private const val STATUS_ACTIVE = "active"
        private const val STATUS_GRACE = "grace"
        private const val STATUS_EXPIRED = "expired"
        private const val STATUS_REVOKED = "revoked"
        private const val ACCESS_FULL = "full"
        private const val ACCESS_READ_ONLY = "read_only"
        private const val LIFETIME_PRODUCT_ID = "dev.iamshift.todo.plus.lifetime"
        private val ACTIVE_STATUSES = setOf(STATUS_ACTIVE, STATUS_GRACE)
        private val READ_ONLY_STATUSES = setOf(STATUS_EXPIRED, STATUS_REVOKED)
        private val PLUS_ENTITLEMENTS = setOf(ENTITLEMENT_PLUS, ENTITLEMENT_LEGACY_31)
        private val FOUNDING_ENTITLEMENTS = setOf(ENTITLEMENT_FOUNDING_SUPPORTER, ENTITLEMENT_LEGACY_31)
    }

    private val fullRecords: List<AccountEntitlementRecord>
        get() = records.filter {
            it.status in ACTIVE_STATUSES && it.accessMode == ACCESS_FULL
        }

    val hasFullPlus: Boolean
        get() = fullRecords.any { it.entitlementKey in PLUS_ENTITLEMENTS }

    val isPioneer: Boolean
        get() = fullRecords.any {
            it.entitlementKey == ENTITLEMENT_LEGACY_31 && it.sourceKind == SOURCE_GRANDFATHERING
        }

    val isFoundingSupporter: Boolean
        get() = fullRecords.any { it.entitlementKey in FOUNDING_ENTITLEMENTS }

    val hasLifetimePlus: Boolean
        get() = fullRecords.any {
            it.entitlementKey == ENTITLEMENT_PLUS &&
                it.sourceProductId == LIFETIME_PRODUCT_ID
        }

    val isInGracePeriod: Boolean
        get() = fullRecords.any {
            it.entitlementKey in PLUS_ENTITLEMENTS && it.status == STATUS_GRACE
        }

    val hasReadOnlyWebAccess: Boolean
        get() = records.any {
            it.entitlementKey in PLUS_ENTITLEMENTS &&
                it.status in READ_ONLY_STATUSES &&
                it.accessMode == ACCESS_READ_ONLY
        }

    val includesFuturePaidFeatures: Boolean
        get() = isPioneer

    val membershipLabel: String
        get() = when {
            isPioneer -> "toDō Pioneer"
            isFoundingSupporter -> "Founding Supporter"
            hasLifetimePlus -> "Lifetime"
            isInGracePeriod -> "Grace Period"
            hasFullPlus -> "Active"
            hasReadOnlyWebAccess -> "Limited Access"
            else -> "Free"
        }

}

/** Auth implementations expose session state without making the domain depend on an SDK. */
interface AuthSessionProvider {
    val account: StateFlow<AuthenticatedAccount?>
}

/** Small implementation for tests and for the pre-auth development shell. */
class MutableAuthSessionProvider(
    initialAccount: AuthenticatedAccount? = null
) : AuthSessionProvider {
    private val _account = MutableStateFlow(initialAccount)
    override val account: StateFlow<AuthenticatedAccount?> = _account.asStateFlow()

    fun setAccount(account: AuthenticatedAccount?) {
        _account.value = account
    }
}

/** Converts the active account into the scope required by remote sync operations. */
class AuthenticatedSyncScopeProvider(
    private val sessionProvider: AuthSessionProvider
) {
    fun currentScope(collabId: UUID? = null): SyncScope? =
        sessionProvider.account.value?.let { account ->
            account.takeIf(AuthenticatedAccount::isResolved)
                ?.let { SyncScope(userId = it.userId, collabId = collabId) }
        }
}

object AndroidUsernamePolicy {
    private val pattern = Regex("^[a-z0-9._]{3,30}$")

    fun normalize(value: String): String? {
        val candidate = value.trim().removePrefix("@").lowercase()
        if (!pattern.matches(candidate)) return null
        if (candidate.startsWith('.') || candidate.endsWith('.')) return null
        return candidate
    }
}

/** A provider callback may never replace the canonical account UUID. */
internal fun linkedIdentityMatches(expectedAccountID: UUID, returnedUserID: String?): Boolean =
    returnedUserID?.let { runCatching { UUID.fromString(it) }.getOrNull() } == expectedAccountID
