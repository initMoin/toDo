import Foundation
import Testing
@testable import ToDo

private enum CommerceTestError: Error {
    case rejected
}

@MainActor
private final class CommerceBackendStub: ToDoEntitlementBackendClient {
    var recordsByAccount: [UUID: [ToDoAccountEntitlement]] = [:]
    var linkError: Error?
    var linkedPayloads: [String] = []

    func link(signedTransactionInfo: String, account: ToDoCommerceAccount) async throws {
        if let linkError { throw linkError }
        linkedPayloads.append(signedTransactionInfo)
    }

    func loadEntitlements(account: ToDoCommerceAccount) async throws -> [ToDoAccountEntitlement] {
        recordsByAccount[account.id] ?? []
    }
}

@MainActor
private final class CollaborationBackendStub: ToDoCollaborationBackendClient {
    var snapshotsByAccount: [UUID: ToDoCollaborationSnapshot] = [:]
   var profilesByAccountAndCollab: [UUID: [UUID: [ToDoCollabUserProfile]]] = [:]
   var sentInvitations: [(collabID: UUID, email: String, accountID: UUID)] = []
   var deletedCollabs: [(collabID: UUID, accountID: UUID)] = []
   var leftCollabBatches: [(ids: Set<UUID>, accountID: UUID)] = []

    func loadSnapshot(account: ToDoCommerceAccount) async throws -> ToDoCollaborationSnapshot {
        snapshotsByAccount[account.id] ?? ToDoCollaborationSnapshot(
            collabs: [],
            invitations: [],
            access: .signedOut
        )
    }

    func loadCollabUsers(
        collabID: UUID,
        account: ToDoCommerceAccount
    ) async throws -> [ToDoCollabUserProfile] {
        profilesByAccountAndCollab[account.id]?[collabID] ?? []
    }

    func loadInvitationDetails(
        id: UUID,
        account: ToDoCommerceAccount
    ) async throws -> ToDoCollabInvitationDetails {
        throw ToDoCollaborationError.invalidServerResponse
    }

    func createCollab(name: String, account: ToDoCommerceAccount) async throws -> ToDoCollab {
        ToDoCollab(
            id: UUID(),
            ownerUserID: account.id,
            name: name,
            createdAt: "2026-07-16T00:00:00Z",
            updatedAt: "2026-07-16T00:00:00Z"
        )
    }

    func sendInvitation(collabID: UUID, email: String, account: ToDoCommerceAccount) async throws {
        sentInvitations.append((collabID, email, account.id))
    }

    func acceptInvitation(id: UUID, account: ToDoCommerceAccount) async throws {}
    func declineInvitation(id: UUID, account: ToDoCommerceAccount) async throws {}
    func cancelInvitation(id: UUID, account: ToDoCommerceAccount) async throws {}
    func removeUser(collabID: UUID, userID: UUID, account: ToDoCommerceAccount) async throws {}
    func deleteCollab(collabID: UUID, account: ToDoCommerceAccount) async throws {
       deletedCollabs.append((collabID, account.id))
    }
    func leaveCollabs(ids: [UUID], account: ToDoCommerceAccount) async throws {
        leftCollabBatches.append((Set(ids), account.id))
    }
}

@MainActor
@Suite("Commerce contract")
struct CommerceContractTests {
    @Test func collaborationInviteLinksRoundTrip() throws {
        let invitationID = try #require(UUID(uuidString: "A1D5A76A-1F14-4C1D-8A15-5D647C3A5A4B"))
        let url = try #require(ToDoCollaborationInviteLink.url(for: invitationID))

        #expect(ToDoCollaborationInviteLink.invitationID(from: url) == invitationID)
    }

    @Test func productIdentifiersAreUniqueAndStable() {
        let identifiers = ToDoProductCatalog.ProductID.allCases.map(\.rawValue)

        #expect(Set(identifiers).count == identifiers.count)
        #expect(ToDoProductCatalog.ProductID.plusLifetime.rawValue == "dev.iamshift.todo.plus.lifetime")
        #expect(ToDoProductCatalog.ProductID.appreciationPatron.rawValue == "dev.iamshift.todo.appreciation.patron")
        #expect(ToDoProductCatalog.ProductID.appreciationFounding.rawValue == "dev.iamshift.todo.appreciation.founding")
    }

    @Test func onlyPlusProductsGrantPlusCapabilities() {
        #expect(ToDoProductCatalog.ProductID.plusMonthly.isPlus)
        #expect(ToDoProductCatalog.ProductID.plusYearly.isPlus)
        #expect(ToDoProductCatalog.ProductID.plusLifetime.isPlus)
        #expect(!ToDoProductCatalog.ProductID.appreciationFounding.isPlus)
    }

    @Test func introductoryOffersAreLimitedToTheSharedSubscriptionProducts() {
        #expect(ToDoProductCatalog.introductoryOfferProductIDs == Set([
            ToDoProductCatalog.ProductID.plusMonthly.rawValue,
            ToDoProductCatalog.ProductID.plusYearly.rawValue,
        ]))
        #expect(!ToDoProductCatalog.introductoryOfferProductIDs.contains(
            ToDoProductCatalog.ProductID.plusLifetime.rawValue
        ))
        #expect(ToDoProductCatalog.introductoryOfferProductIDs.isSubset(of: ToDoProductCatalog.plusProductIDs))
    }

    @Test func freeAndPlusCollaborationContractsStayDistinct() {
        #expect(ToDoCapabilities.free.accessLevel == .free)
        #expect(ToDoCapabilities.plus.accessLevel == .plus)
        #expect(ToDoCapabilities.legacy.accessLevel == .legacy)
        #expect(!ToDoCapabilities.free.includesFuturePaidFeatures)
        #expect(!ToDoCapabilities.plus.includesFuturePaidFeatures)
        #expect(ToDoCapabilities.legacy.includesFuturePaidFeatures)
        #expect(ToDoCapabilities.free.outgoingInvitationLimit == 2)
        #expect(ToDoCapabilities.free.canJoinUnlimitedSharedLists)
        #expect(!ToDoCapabilities.free.hasWebAccess)
        #expect(ToDoCapabilities.plus.outgoingInvitationLimit == nil)
        #expect(ToDoCapabilities.plus.canJoinUnlimitedSharedLists)
        #expect(ToDoCapabilities.plus.hasWebAccess)
        #expect(ToDoCapabilities.plus.availableRoles == [.owner, .user])
        #expect(ToDoCapabilities.legacy.outgoingInvitationLimit == nil)
        #expect(ToDoCapabilities.legacy.hasWebAccess)
        #expect(ToDoCollaborationRole.user.rawValue == "user")
    }

    @Test func missingCollabSchemaIsRecognizedWithoutMaskingOtherFailures() {
        let missingSchema = ToDoCollaborationError.requestFailed(
            statusCode: 404,
            message: "Could not find the table 'public.collabs' in the schema cache"
        )
        let denied = ToDoCollaborationError.requestFailed(
            statusCode: 403,
            message: "Permission denied for table collabs"
        )
        let unrelatedMissingTable = ToDoCollaborationError.requestFailed(
            statusCode: 404,
            message: "Could not find the table 'public.todos' in the schema cache"
        )

        #expect(missingSchema.isMissingBackendSchema)
        #expect(!denied.isMissingBackendSchema)
        #expect(!unrelatedMissingTable.isMissingBackendSchema)
    }

    @Test func freeInvitationPolicyStopsAtTwoAcceptedUsers() {
        #expect(ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: 0,
            capabilities: .free
        ))
        #expect(ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: 1,
            capabilities: .free
        ))
        #expect(!ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: 2,
            capabilities: .free
        ))
        #expect(!ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: 8,
            capabilities: .free
        ))
    }

    @Test func plusInvitationPolicyRemainsUnlimited() {
        #expect(ToDoCollaborationPolicy.canSendInvitation(
            acceptedOutgoingCount: 500,
            capabilities: .plus
        ))
    }

    @Test func inviteEmailPolicyNormalizesValidAddressesAndRejectsMalformedInput() {
        #expect(ToDoCollaborationPolicy.normalizedInviteEmail(" Person@Example.COM ") == "person@example.com")
        #expect(ToDoCollaborationPolicy.normalizedInviteEmail("person@example.com") == "person@example.com")
        #expect(ToDoCollaborationPolicy.normalizedInviteEmail("person@example") == nil)
        #expect(ToDoCollaborationPolicy.normalizedInviteEmail("person example.com") == nil)
        #expect(ToDoCollaborationPolicy.normalizedInviteEmail("@example.com") == nil)
    }

    @Test func collaborationServiceRejectsMalformedInviteBeforeBackendCall() async throws {
        let accountID = UUID()
        let backend = CollaborationBackendStub()
        backend.snapshotsByAccount[accountID] = collaborationSnapshot(
            acceptedCount: 0,
            limit: 2,
            canSend: true
        )
        let service = ToDoCollaborationService(backendClient: backend)
        await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

        await #expect(throws: ToDoCollaborationError.invalidInviteEmail) {
            try await service.sendInvitation(
                collabID: UUID(),
                email: "not-an-email",
                capabilities: .free
            )
        }
        #expect(backend.sentInvitations.isEmpty)
    }

    @Test func collaborationServiceEnforcesLimitBeforeCallingBackend() async throws {
        let accountID = UUID()
        let collabID = UUID()
        let backend = CollaborationBackendStub()
        backend.snapshotsByAccount[accountID] = collaborationSnapshot(
            acceptedCount: 2,
            limit: 2,
            canSend: false
        )
        let service = ToDoCollaborationService(backendClient: backend)
        await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

        await #expect(throws: ToDoCollaborationError.invitationLimitReached(limit: 2)) {
            try await service.sendInvitation(
                collabID: collabID,
                email: "person@example.com",
                capabilities: .free
            )
        }
        #expect(backend.sentInvitations.isEmpty)
    }

    @Test func collabOwnerCanDeleteSharedList() async throws {
       let accountID = UUID()
       let collabID = UUID()
       let backend = CollaborationBackendStub()
       backend.snapshotsByAccount[accountID] = ToDoCollaborationSnapshot(
          collabs: [
             ToDoCollab(
                id: collabID,
                ownerUserID: accountID,
                name: "Project",
                createdAt: "2026-08-06T00:00:00Z",
                updatedAt: "2026-08-06T00:00:00Z"
             ),
          ],
          invitations: [],
          access: .signedOut
       )
       let service = ToDoCollaborationService(backendClient: backend)
       await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

       try await service.deleteCollab(id: collabID)

       #expect(backend.deletedCollabs.map(\.collabID) == [collabID])
       #expect(backend.deletedCollabs.map(\.accountID) == [accountID])
    }

    @Test func collaboratorCannotDeleteSharedList() async {
       let accountID = UUID()
       let ownerID = UUID()
       let collabID = UUID()
       let backend = CollaborationBackendStub()
       backend.snapshotsByAccount[accountID] = ToDoCollaborationSnapshot(
          collabs: [
             ToDoCollab(
                id: collabID,
                ownerUserID: ownerID,
                name: "Shared",
                createdAt: "2026-08-06T00:00:00Z",
                updatedAt: "2026-08-06T00:00:00Z"
             ),
          ],
          invitations: [],
          access: .signedOut
       )
       let service = ToDoCollaborationService(backendClient: backend)
       await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

       await #expect(throws: ToDoCollaborationError.notAuthorized) {
          try await service.deleteCollab(id: collabID)
       }
       #expect(backend.deletedCollabs.isEmpty)
    }

    @Test func collaborationAccountSwitchClearsPriorAccountState() async {
        let firstID = UUID()
        let secondID = UUID()
        let backend = CollaborationBackendStub()
        backend.snapshotsByAccount[firstID] = collaborationSnapshot(
            acceptedCount: 2,
            limit: 2,
            canSend: false
        )
        backend.snapshotsByAccount[secondID] = collaborationSnapshot(
            acceptedCount: 0,
            limit: 2,
            canSend: true
        )
        let service = ToDoCollaborationService(backendClient: backend)

        let collabID = UUID()
        backend.profilesByAccountAndCollab[firstID] = [
            collabID: [
                ToDoCollabUserProfile(
                    userID: firstID,
                    username: nil,
                    displayName: "First Account",
                    avatarURL: nil,
                    role: .owner,
                    collabID: collabID,
                    collabName: "First Collab"
                ),
            ],
        ]

        await service.updateAccount(ToDoCommerceAccount(id: firstID, accessToken: "first"))
        await service.loadCollabUsers(collabID: collabID)
        #expect(service.access.acceptedOutgoingCount == 2)
        #expect(!service.canSendInvitation(capabilities: .free))
        #expect(service.profiles(for: collabID).map(\.displayName) == ["First Account"])

        await service.updateAccount(ToDoCommerceAccount(id: secondID, accessToken: "second"))
        #expect(service.access.acceptedOutgoingCount == 0)
        #expect(service.canSendInvitation(capabilities: .free))
        #expect(service.profiles(for: collabID).isEmpty)

        await service.updateAccount(nil)
        #expect(service.access == .signedOut)
        #expect(service.collabs.isEmpty)
        #expect(service.invitations.isEmpty)
        #expect(service.profilesByCollabID.isEmpty)
    }

    @Test func emptyCollaborationSnapshotIsStillConsideredLoaded() async {
        let accountID = UUID()
        let backend = CollaborationBackendStub()
        backend.snapshotsByAccount[accountID] = ToDoCollaborationSnapshot(
            collabs: [],
            invitations: [],
            access: .signedOut
        )
        let service = ToDoCollaborationService(backendClient: backend)

        await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

        #expect(service.hasLoadedSnapshot)
        #expect(!service.isLoading)
        #expect(service.collabs.isEmpty)
        #expect(service.invitations.isEmpty)
    }

    @Test func leavingSharedCollabsExcludesListsOwnedByCurrentAccount() async throws {
        let accountID = UUID()
        let ownedID = UUID()
        let joinedID = UUID()
        let backend = CollaborationBackendStub()
        backend.snapshotsByAccount[accountID] = ToDoCollaborationSnapshot(
            collabs: [
                ToDoCollab(
                    id: ownedID,
                    ownerUserID: accountID,
                    name: "Owned",
                    createdAt: "2026-07-18T00:00:00Z",
                    updatedAt: "2026-07-18T00:00:00Z"
                ),
                ToDoCollab(
                    id: joinedID,
                    ownerUserID: UUID(),
                    name: "Joined",
                    createdAt: "2026-07-18T00:00:00Z",
                    updatedAt: "2026-07-18T00:00:00Z"
                ),
            ],
            invitations: [],
            access: .signedOut
        )
        let service = ToDoCollaborationService(backendClient: backend)
        await service.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

        let result = try await service.leaveSharedCollabs()

        #expect(result.leftCollabIDs == Set([joinedID]))
        #expect(result.preservedOwnedCollabCount == 1)
        #expect(backend.leftCollabBatches.count == 1)
        #expect(backend.leftCollabBatches.first?.ids == Set([joinedID]))
    }

    @Test func foundingSupportIsRestorableButOtherAppreciationIsRepeatable() {
        #expect(ToDoProductCatalog.restorableProductIDs.contains(ToDoProductCatalog.ProductID.appreciationFounding.rawValue))
        #expect(!ToDoProductCatalog.ProductID.appreciationFounding.isRepeatableAppreciation)
        #expect(ToDoProductCatalog.ProductID.appreciationCoffee.isRepeatableAppreciation)
        #expect(ToDoProductCatalog.ProductID.appreciationLunch.isRepeatableAppreciation)
        #expect(ToDoProductCatalog.ProductID.appreciationPatron.isRepeatableAppreciation)
    }

    @Test func repeatableSupportNeverRestoresOrUnlocksCapabilities() {
        let repeatableProducts: [ToDoProductCatalog.ProductID] = [
            .appreciationCoffee,
            .appreciationLunch,
            .appreciationPatron,
        ]

        for product in repeatableProducts {
            #expect(product.isRepeatableAppreciation)
            #expect(!product.isPlus)
            #expect(!ToDoProductCatalog.restorableProductIDs.contains(product.rawValue))
        }

        #expect(ToDoProductCatalog.restorableProductIDs == Set([
            ToDoProductCatalog.ProductID.plusMonthly.rawValue,
            ToDoProductCatalog.ProductID.plusYearly.rawValue,
            ToDoProductCatalog.ProductID.plusLifetime.rawValue,
            ToDoProductCatalog.ProductID.appreciationFounding.rawValue,
        ]))
    }

    @Test func serverEntitlementsHandleGraceReadOnlyLifetimeAndFoundingStates() {
        let accountID = UUID()
        let snapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .plus, status: .grace, access: .full),
            entitlement(accountID: accountID, key: .foundingSupporter, status: .active, access: .full),
        ])

        #expect(snapshot.hasFullPlus)
        #expect(snapshot.isInGracePeriod)
        #expect(snapshot.isFoundingSupporter)
        #expect(!snapshot.hasReadOnlyWebAccess)

        let readOnlySnapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .plus, status: .expired, access: .readOnly),
        ])
        #expect(!readOnlySnapshot.hasFullPlus)
        #expect(readOnlySnapshot.hasReadOnlyWebAccess)

        let grandfatheredSnapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .legacy31, status: .active, access: .full),
        ])
        #expect(grandfatheredSnapshot.hasFullPlus)
        #expect(!grandfatheredSnapshot.hasLifetimePlus)
        #expect(grandfatheredSnapshot.isFoundingSupporter)
        #expect(grandfatheredSnapshot.isGrandfatheredFor31)

        let grandfatheredGraceSnapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .legacy31, status: .grace, access: .full),
        ])
        #expect(grandfatheredGraceSnapshot.isFoundingSupporter)
        #expect(grandfatheredGraceSnapshot.isGrandfatheredFor31)

        let purchasedLifetimeSnapshot = ToDoEntitlementSnapshot(records: [
            ToDoAccountEntitlement(
                accountID: accountID,
                entitlementKey: .plus,
                status: .active,
                accessMode: .full,
                ownershipType: "PURCHASED",
                expiresAt: nil,
                webReadOnlyUntil: nil,
                sourceKind: "apple_iap",
                sourceProductID: ToDoProductCatalog.ProductID.plusLifetime.rawValue,
                updatedAt: "2026-07-15T00:00:00Z"
            ),
        ])
        #expect(purchasedLifetimeSnapshot.hasLifetimePlus)
        #expect(!purchasedLifetimeSnapshot.isGrandfatheredFor31)
    }

    @Test func familySharingGrantsTheSameVerifiedPlusCapability() {
        let accountID = UUID()
        let snapshot = ToDoEntitlementSnapshot(records: [
            entitlement(
                accountID: accountID,
                key: .plus,
                status: .active,
                access: .full,
                ownershipType: "FAMILY_SHARED"
            ),
        ])

        #expect(snapshot.hasFullPlus)
        #expect(!snapshot.hasReadOnlyWebAccess)
    }

    @Test func expiredAndRevokedRowsNeverGrantFullCapabilities() {
        let accountID = UUID()
        let malformedRevokedSnapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .plus, status: .revoked, access: .full),
        ])
        #expect(!malformedRevokedSnapshot.hasFullPlus)
        #expect(!malformedRevokedSnapshot.hasReadOnlyWebAccess)

        let serverAuthorizedReadOnlySnapshot = ToDoEntitlementSnapshot(records: [
            entitlement(accountID: accountID, key: .plus, status: .revoked, access: .readOnly),
        ])
        #expect(!serverAuthorizedReadOnlySnapshot.hasFullPlus)
        #expect(serverAuthorizedReadOnlySnapshot.hasReadOnlyWebAccess)
    }

    @Test func switchingAccountsClearsPriorServerCapabilities() async {
        let firstID = UUID()
        let secondID = UUID()
        let backend = CommerceBackendStub()
        backend.recordsByAccount[firstID] = [
            entitlement(accountID: firstID, key: .plus, status: .active, access: .full),
        ]
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)

        await manager.updateAccount(ToDoCommerceAccount(id: firstID, accessToken: "first-token"))
        #expect(manager.hasPlus)
        #expect(manager.accountEntitlements.allSatisfy { $0.accountID == firstID })

        await manager.updateAccount(ToDoCommerceAccount(id: secondID, accessToken: "second-token"))
        #expect(!manager.hasPlus)
        #expect(manager.accountEntitlements.isEmpty)

        await manager.updateAccount(nil)
        #expect(manager.accountID == nil)
        #expect(manager.accountEntitlements.isEmpty)
    }

    @Test func backendLinkFailureDoesNotGrantAccountCapabilities() async {
        let backend = CommerceBackendStub()
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)
        await manager.updateAccount(ToDoCommerceAccount(id: UUID(), accessToken: "token"))
        backend.linkError = CommerceTestError.rejected

        let linked = await manager.connectVerifiedTransaction("signed-jws")

        #expect(!linked)
        #expect(!manager.hasPlus)
        #expect(manager.errorMessage == "Your purchase is safe, but toDō could not connect it to this account yet.")
    }

    @Test func conflictingAccountLinkNeverLeaksCapabilities() async {
        let backend = CommerceBackendStub()
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)
        await manager.updateAccount(ToDoCommerceAccount(id: UUID(), accessToken: "token"))
        backend.linkError = ToDoCommerceBackendError.requestFailed(
            statusCode: 409,
            message: "This purchase is already connected to another account."
        )

        let linked = await manager.connectVerifiedTransaction("signed-jws")

        #expect(!linked)
        #expect(!manager.hasPlus)
        #expect(manager.accountEntitlements.isEmpty)
    }

    @Test func successfulBackendLinkReloadsEffectiveEntitlements() async {
        let accountID = UUID()
        let backend = CommerceBackendStub()
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)
        await manager.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))
        backend.recordsByAccount[accountID] = [
            entitlement(accountID: accountID, key: .plus, status: .active, access: .full),
        ]

        let linked = await manager.connectVerifiedTransaction("signed-jws")

        #expect(linked)
        #expect(backend.linkedPayloads == ["signed-jws"])
        #expect(manager.hasPlus)
    }

    @Test func legacyAccountSnapshotGrantsDurableAccessWithoutStoreKitEvidence() async {
        let accountID = UUID()
        let backend = CommerceBackendStub()
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)
        await manager.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))
        backend.recordsByAccount[accountID] = [
            entitlement(accountID: accountID, key: .legacy31, status: .active, access: .full),
        ]

        await manager.refreshEntitlements()

        #expect(manager.hasPlus)
        #expect(manager.membershipLabel == "toDō Pioneer")
        #expect(manager.includesFuturePaidFeatures)
        #expect(manager.capabilities.accessLevel == .legacy)
        #expect(!manager.shouldShowPlusPurchaseOptions)
        #expect(!manager.shouldShowFoundingSupporterPurchase)
    }

    @Test func purchaseMerchandisingHidesOwnedOneTimeChoices() async {
        let accountID = UUID()
        let backend = CommerceBackendStub()
        let manager = ToDoPurchaseManager(loadsStoreProducts: false, backendClient: backend)
        await manager.updateAccount(ToDoCommerceAccount(id: accountID, accessToken: "token"))

        backend.recordsByAccount[accountID] = [
            entitlement(accountID: accountID, key: .foundingSupporter, status: .active, access: .full)
        ]
        await manager.refreshEntitlements()

        #expect(manager.shouldShowPlusPurchaseOptions)
        #expect(!manager.shouldShowFoundingSupporterPurchase)
    }

    private func entitlement(
        accountID: UUID,
        key: ToDoAccountEntitlement.EntitlementKey,
        status: ToDoAccountEntitlement.Status,
        access: ToDoAccountEntitlement.AccessMode,
        ownershipType: String = "PURCHASED"
    ) -> ToDoAccountEntitlement {
        ToDoAccountEntitlement(
            accountID: accountID,
            entitlementKey: key,
            status: status,
            accessMode: access,
            ownershipType: ownershipType,
            expiresAt: nil,
            webReadOnlyUntil: nil,
            sourceKind: key == .legacy31 ? "grandfathering" : "apple_iap",
            sourceProductID: key == .plus ? ToDoProductCatalog.ProductID.plusMonthly.rawValue : nil,
            updatedAt: "2026-07-15T00:00:00Z"
        )
    }

    private func collaborationSnapshot(
        acceptedCount: Int,
        limit: Int?,
        canSend: Bool
    ) -> ToDoCollaborationSnapshot {
        ToDoCollaborationSnapshot(
            collabs: [],
            invitations: [],
            access: ToDoCollaborationAccess(
                acceptedOutgoingCount: acceptedCount,
                outgoingInvitationLimit: limit,
                hasUnlimitedCollaboration: limit == nil,
                canSendInvitation: canSend
            )
        )
    }
}
