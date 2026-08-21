package dev.iamshift.todo.android.core.auth

import android.content.Intent
import dev.iamshift.todo.android.core.supabase.SupabaseService
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.handleDeeplinks
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

enum class SupabaseOAuthProvider {
    APPLE,
    GOOGLE
}

/** Supabase Auth adapter that exposes only provider-neutral account state. */
class SupabaseAuthSessionProvider(
    clientFactory: () -> SupabaseClient = { SupabaseService.client },
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
) : AuthSessionProvider {
    // Client construction can load Ktor/Auth persistence. Keep it lazy so a
    // cold Compose launch does not initialize Supabase on the UI thread.
    private val client: SupabaseClient by lazy(clientFactory)
    private val _account = MutableStateFlow<AuthenticatedAccount?>(null)
    override val account: StateFlow<AuthenticatedAccount?> = _account.asStateFlow()
    private var pendingIntent = AccountAuthenticationIntent.RESTORE_SESSION
    private var pendingExpectedUsername: String? = null

    init {
        scope.launch {
            client.auth.sessionStatus.collectLatest { status ->
                val account = status.authenticatedAccountOrNull()
                if (account == null) {
                    _account.value = null
                } else {
                    resolveAccount(account)
                }
            }
        }
    }

    suspend fun start() {
        client.auth.awaitInitialization()
        if (client.auth.sessionStatus.value is SessionStatus.Authenticated) {
            client.auth.startAutoRefreshForCurrentSession()
        }
    }

    suspend fun signIn(
        provider: SupabaseOAuthProvider,
        intent: AccountAuthenticationIntent = AccountAuthenticationIntent.SIGN_IN,
        expectedUsername: String? = null
    ) {
        pendingIntent = intent
        pendingExpectedUsername = AndroidUsernamePolicy.normalize(expectedUsername.orEmpty())
        _account.value = null
        when (provider) {
            SupabaseOAuthProvider.APPLE -> client.auth.signInWith(Apple)
            SupabaseOAuthProvider.GOOGLE -> client.auth.signInWith(Google)
        }
    }

    suspend fun signOut() {
        client.auth.signOut()
        _account.value = null
    }

    /** Starts an explicit second-provider connection from an already resolved account. */
    suspend fun connectProvider(provider: SupabaseOAuthProvider) {
        val expectedAccountID = _account.value
            ?.takeIf(AuthenticatedAccount::isResolved)
            ?.userId
        check(expectedAccountID != null) {
            "Resolve the toDō account before connecting another sign-in method."
        }

        when (provider) {
            SupabaseOAuthProvider.APPLE -> client.auth.linkIdentity(Apple)
            SupabaseOAuthProvider.GOOGLE -> client.auth.linkIdentity(Google)
        }

        check(linkedIdentityMatches(expectedAccountID, client.auth.currentUserOrNull()?.id)) {
            "The connected sign-in method did not preserve the current toDō account."
        }

        refreshResolvedAccount()
    }

    /** Refreshes profile and linked-provider state after an account action. */
    suspend fun refreshResolvedAccount() {
        val user = client.auth.currentUserOrNull() ?: return
        val userId = user.id.toUuidOrNull() ?: return
        resolveAccount(
            AuthenticatedAccount(
                userId = userId,
                email = user.email,
                linkedProviders = user.identities.orEmpty()
                    .map { it.provider.lowercase() }
                    .toSet()
            )
        )
    }

    /** Stores the shared Android profile image in the account-scoped Supabase bucket. */
    suspend fun updateProfileImage(imageData: ByteArray): Boolean {
        require(imageData.isNotEmpty()) { "The profile image is empty." }
        require(imageData.size <= MAX_PROFILE_IMAGE_BYTES) {
            "Choose an image smaller than 5 MB."
        }

        val account = _account.value?.takeIf(AuthenticatedAccount::isResolved)
            ?: return false
        val authenticatedUserID = client.auth.currentUserOrNull()?.id?.toUuidOrNull()
        check(authenticatedUserID == account.userId) {
            "The authenticated account changed before the profile image was saved."
        }

        val path = "${account.userId.toString().lowercase()}/avatar.jpg"
        val bucket = client.storage.from(PROFILE_IMAGE_BUCKET)
        bucket.upload(path, imageData) {
            contentType = ContentType.Image.JPEG
            upsert = true
        }

        val avatarUrl = "${bucket.publicUrl(path)}?v=${System.currentTimeMillis()}"
        client.from("profiles").update(ProfileAvatarUpdate(avatarUrl)) {
            filter { eq("id", account.userId.toString()) }
        }
        refreshResolvedAccount()
        return _account.value?.avatarUrl?.startsWith(bucket.publicUrl(path)) == true
    }

    suspend fun completeAccountSetup(username: String): Boolean {
        val normalized = AndroidUsernamePolicy.normalize(username) ?: return false
        val account = _account.value ?: return false
        return runCatching {
            val response = client.postgrest.rpc(
                function = "claim_account_username",
                parameters = UsernameClaimParameters(normalized)
            ).decodeList<UsernameClaimResponse>().firstOrNull()
            response != null && response.accountId.toUuidOrNull() == account.userId && response.username == normalized
        }.getOrDefault(false).also { claimed ->
            if (claimed) {
                pendingIntent = AccountAuthenticationIntent.RESTORE_SESSION
                pendingExpectedUsername = normalized
                resolveAccount(account.copy(username = normalized))
            }
        }
    }

    suspend fun continueWithAuthenticatedAccount(): Boolean {
        val account = _account.value ?: return false
        val username = account.username ?: return false
        pendingIntent = AccountAuthenticationIntent.RESTORE_SESSION
        pendingExpectedUsername = username
        resolveAccount(account)
        return _account.value?.isResolved == true
    }

    fun handleDeepLink(intent: Intent, onError: (Throwable) -> Unit = {}) {
        // supabase-kt 3.2.x reports callback failures through Auth.events.
        // Newer releases also expose an onError callback; keeping this call
        // version-neutral lets the service upgrade without affecting callers.
        runCatching { client.handleDeeplinks(intent) }
            .onFailure(onError)
    }

    fun close() {
        scope.cancel()
    }

    private suspend fun resolveAccount(account: AuthenticatedAccount) {
        _account.value = account.copy(
            resolutionState = AccountResolutionState.RESOLVING,
            resolutionMessage = null
        )

        val profile = runCatching {
            client.from("profiles")
                .select {
                    filter { eq("id", account.userId.toString()) }
                }
                .decodeList<AndroidProfileResolutionRecord>()
                .firstOrNull()
        }.getOrElse { error ->
            _account.value = account.copy(
                resolutionState = AccountResolutionState.NEEDS_USERNAME,
                resolutionMessage = error.message ?: "Your toDō account could not be resolved."
            )
            return
        }

        if (profile == null || profile.username.isNullOrBlank()) {
            if (pendingIntent == AccountAuthenticationIntent.CREATE_ACCOUNT && pendingExpectedUsername != null) {
                if (completeAccountSetup(pendingExpectedUsername!!)) return
            }
            _account.value = account.copy(
                resolutionState = AccountResolutionState.NEEDS_USERNAME,
                resolutionMessage = "Choose a username before sync can begin."
            )
            return
        }

        val accountAccess = loadAccountAccess(account.userId)

        val username = profile.username
        if ((profile.accountSetupVersion ?: 1) < 2) {
            _account.value = account.copy(
                username = username,
                displayName = profile.displayName,
                avatarUrl = profile.avatarUrl,
                accountRole = accountAccess.role,
                entitlements = accountAccess.entitlements,
                accountSetupVersion = profile.accountSetupVersion,
                resolutionState = AccountResolutionState.MIGRATION_REQUIRED,
                resolutionMessage = "Confirm @${username} to finish your one-time account setup."
            )
            return
        }

        val expected = pendingExpectedUsername
        if (expected != null && pendingIntent != AccountAuthenticationIntent.RESTORE_SESSION && expected != username) {
            _account.value = account.copy(
                username = username,
                displayName = profile.displayName,
                avatarUrl = profile.avatarUrl,
                accountRole = accountAccess.role,
                entitlements = accountAccess.entitlements,
                accountSetupVersion = profile.accountSetupVersion,
                resolutionState = AccountResolutionState.ACCOUNT_MISMATCH,
                resolutionMessage = "This provider signs in to @$username, not @$expected."
            )
            return
        }

        _account.value = account.copy(
            username = username,
            displayName = profile.displayName,
            avatarUrl = profile.avatarUrl,
            accountRole = accountAccess.role,
            entitlements = accountAccess.entitlements,
            accountSetupVersion = profile.accountSetupVersion,
            resolutionState = AccountResolutionState.RESOLVED,
            resolutionMessage = null
        )
    }

    private suspend fun loadAccountAccess(accountId: UUID): AccountAccess {
        val entitlements = runCatching {
            client.from("current_account_entitlements")
                .select {
                    filter { eq("account_id", accountId.toString()) }
                }
                .decodeList<AndroidAccountEntitlementRecord>()
                .map {
                    AccountEntitlementRecord(
                        entitlementKey = it.entitlementKey,
                        status = it.status,
                        accessMode = it.accessMode,
                        sourceKind = it.sourceKind,
                        sourceProductId = it.sourceProductId
                    )
                }
        }.getOrDefault(emptyList())

        val role = runCatching {
            client.from("account_roles")
                .select {
                    filter { eq("account_id", accountId.toString()) }
                }
                .decodeList<AndroidAccountRoleRecord>()
                .firstOrNull()
                ?.role
        }.getOrNull()

        return AccountAccess(
            entitlements = AccountEntitlements(entitlements),
            role = role
        )
    }
}

private data class AccountAccess(
    val entitlements: AccountEntitlements,
    val role: String?
)

private fun SessionStatus.authenticatedAccountOrNull(): AuthenticatedAccount? {
    val session = this as? SessionStatus.Authenticated ?: return null
    val user = session.session.user ?: return null
    val userId = user.id.toUuidOrNull() ?: return null
    return AuthenticatedAccount(
        userId = userId,
        email = user.email,
        linkedProviders = user.identities.orEmpty().map { it.provider.lowercase() }.toSet()
    )
}

private fun String.toUuidOrNull(): UUID? = runCatching { UUID.fromString(this) }.getOrNull()

private const val PROFILE_IMAGE_BUCKET = "profile-images"
private const val MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024

@kotlinx.serialization.Serializable
private data class ProfileAvatarUpdate(
    @kotlinx.serialization.SerialName("avatar_url") val avatarUrl: String
)
