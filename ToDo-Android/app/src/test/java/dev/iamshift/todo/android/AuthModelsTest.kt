package dev.iamshift.todo.android

import dev.iamshift.todo.android.core.auth.AuthenticatedAccount
import dev.iamshift.todo.android.core.auth.AuthenticatedSyncScopeProvider
import dev.iamshift.todo.android.core.auth.AccountEntitlementRecord
import dev.iamshift.todo.android.core.auth.AccountEntitlements
import dev.iamshift.todo.android.core.auth.AccountResolutionState
import dev.iamshift.todo.android.core.auth.MutableAuthSessionProvider
import dev.iamshift.todo.android.core.auth.linkedIdentityMatches
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AuthModelsTest {
    @Test
    fun scopeExistsOnlyForAnAuthenticatedAccount() {
        val session = MutableAuthSessionProvider()
        val scopeProvider = AuthenticatedSyncScopeProvider(session)

        assertNull(scopeProvider.currentScope())

        val userId = UUID.fromString("00000000-0000-0000-0000-000000000031")
        session.setAccount(
            AuthenticatedAccount(
                userId = userId,
                username = "tester",
                accountSetupVersion = 2,
                resolutionState = AccountResolutionState.RESOLVED
            )
        )

        assertEquals(userId, scopeProvider.currentScope()?.userId)
    }

    @Test
    fun unresolvedProviderSessionCannotCreateSyncScope() {
        val userId = UUID.fromString("00000000-0000-0000-0000-000000000032")
        val session = MutableAuthSessionProvider(
            AuthenticatedAccount(userId = userId, resolutionState = AccountResolutionState.NEEDS_USERNAME)
        )

        assertNull(AuthenticatedSyncScopeProvider(session).currentScope())
    }

    @Test
    fun linkedProviderMustKeepTheCanonicalAccountUUID() {
        val accountID = UUID.fromString("00000000-0000-0000-0000-000000000033")

        assertEquals(true, linkedIdentityMatches(accountID, accountID.toString()))
        assertEquals(false, linkedIdentityMatches(accountID, "00000000-0000-0000-0000-000000000034"))
        assertEquals(false, linkedIdentityMatches(accountID, "not-a-uuid"))
    }

    @Test
    fun pioneerEntitlementUnlocksFullPlusAndFutureCapabilities() {
        val entitlements = AccountEntitlements(
            records = listOf(
                AccountEntitlementRecord(
                    entitlementKey = "legacy_3_1",
                    status = "active",
                    accessMode = "full",
                    sourceKind = "grandfathering"
                )
            )
        )

        assertEquals(true, entitlements.hasFullPlus)
        assertEquals(true, entitlements.isPioneer)
        assertEquals(true, entitlements.includesFuturePaidFeatures)
        assertEquals("toDō Pioneer", entitlements.membershipLabel)
    }

    @Test
    fun foundingRecognitionDoesNotBecomePlusAccess() {
        val entitlements = AccountEntitlements(
            records = listOf(
                AccountEntitlementRecord(
                    entitlementKey = "founding_supporter",
                    status = "active",
                    accessMode = "full",
                    sourceKind = "support"
                )
            )
        )

        assertEquals(false, entitlements.hasFullPlus)
        assertEquals(true, entitlements.isFoundingSupporter)
        assertEquals("Founding Supporter", entitlements.membershipLabel)
    }

    @Test
    fun expiredEntitlementIsLimitedReadOnlyAccess() {
        val entitlements = AccountEntitlements(
            records = listOf(
                AccountEntitlementRecord(
                    entitlementKey = "todo_plus",
                    status = "expired",
                    accessMode = "read_only",
                    sourceKind = "apple_iap"
                )
            )
        )

        assertEquals(false, entitlements.hasFullPlus)
        assertEquals(true, entitlements.hasReadOnlyWebAccess)
        assertEquals("Limited Access", entitlements.membershipLabel)
    }
}
