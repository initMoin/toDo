import Foundation
import SwiftData
import Testing
@testable import ToDo

@Suite("Sync migration planning")
@MainActor
struct SyncMigrationPlanTests {
    @Test func everyDistinctSyncModeTransitionHasAPlan() {
        for sourceMode in SyncMode.allCases {
            for destinationMode in SyncMode.allCases where sourceMode != destinationMode {
                #expect(MigrationService.shared.plan(from: sourceMode, to: destinationMode) != nil)
            }
        }
    }

    @Test func cloudKitTransitionsRequireRelaunch() throws {
        for direction in SyncMigrationDirection.allCases {
            let plan = try #require(
                MigrationService.shared.plan(
                    from: direction.sourceMode,
                    to: direction.destinationMode
                )
            )

            #expect(plan.requiresRelaunchToApply == direction.touchesCloudKitStore)
        }
    }

    @Test func todoSyncDestinationsRequireAuthenticatedAccount() throws {
        for direction in SyncMigrationDirection.allCases {
            let plan = try #require(
                MigrationService.shared.plan(
                    from: direction.sourceMode,
                    to: direction.destinationMode
                )
            )

            #expect(plan.requiresAuthenticatedSupabaseAccount == (direction.destinationMode == .syncEverywhere))
        }
    }

    @Test func anonymousDataAdoptionRequiresAnExplicitAccountMatchedTransfer() throws {
        let suiteName = "SyncMigrationPlanTests.adoption"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountA = UUID()
        let accountB = UUID()
        let configuration = ModelConfiguration(
            UUID().uuidString,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: ToDo.self,
            Tag.self,
            NanoDo.self,
            configurations: configuration
        )
        let migrationService = MigrationService()
        migrationService.configure(modelContainer: container)

        try migrationService.executeIfNeeded(
            from: .deviceOnly,
            to: .syncEverywhere,
            userID: accountA,
            shouldTransferData: true,
            userDefaults: defaults
        )

        #expect(migrationService.hasPendingLocalDataAdoption(for: accountA, userDefaults: defaults))
        #expect(!migrationService.hasPendingLocalDataAdoption(for: accountB, userDefaults: defaults))

        migrationService.clearPendingLocalDataAdoption(for: accountA, userDefaults: defaults)
        #expect(!migrationService.hasPendingLocalDataAdoption(for: accountA, userDefaults: defaults))
    }

    @Test func decliningTransferNeverAuthorizesAnonymousDataAdoption() throws {
        let suiteName = "SyncMigrationPlanTests.noAdoption"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountID = UUID()
        let configuration = ModelConfiguration(
            UUID().uuidString,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: ToDo.self,
            Tag.self,
            NanoDo.self,
            configurations: configuration
        )
        let migrationService = MigrationService()
        migrationService.configure(modelContainer: container)

        try migrationService.executeIfNeeded(
            from: .deviceOnly,
            to: .syncEverywhere,
            userID: accountID,
            shouldTransferData: true,
            userDefaults: defaults
        )
        #expect(migrationService.hasPendingLocalDataAdoption(for: accountID, userDefaults: defaults))

        try migrationService.executeIfNeeded(
            from: .deviceOnly,
            to: .syncEverywhere,
            userID: accountID,
            shouldTransferData: false,
            userDefaults: defaults
        )

        #expect(!migrationService.hasPendingLocalDataAdoption(for: accountID, userDefaults: defaults))
    }
}

@Suite("Account data scope")
struct AccountDataScopeTests {
    @Test func unsignedScopeExcludesEveryAccountOwner() {
        let accountA = UUID()
        let accountB = UUID()
        let scope = ToDoDataScope(resolvedAccountID: nil)

        #expect(scope.includes(ownerUserID: nil))
        #expect(!scope.includes(ownerUserID: accountA))
        #expect(!scope.includes(ownerUserID: accountB))
    }

    @Test func resolvedAccountScopeExcludesUnsignedAndOtherAccountRows() {
        let accountA = UUID()
        let accountB = UUID()
        let scope = ToDoDataScope(resolvedAccountID: accountA)

        #expect(scope.includes(ownerUserID: accountA))
        #expect(!scope.includes(ownerUserID: nil))
        #expect(!scope.includes(ownerUserID: accountB))
    }

    @Test func signingBackIntoTheSameAccountRestoresTheSameNamespace() {
        let accountID = UUID()
        let originalScope = ToDoDataScope(resolvedAccountID: accountID)
        let signedOutScope = ToDoDataScope(resolvedAccountID: nil)
        let restoredScope = ToDoDataScope(resolvedAccountID: accountID)

        #expect(originalScope == restoredScope)
        #expect(originalScope != signedOutScope)
        #expect(restoredScope.includes(ownerUserID: accountID))
    }

   @Test func unresolvedProviderSessionCannotExposeAccountRows() {
        let accountID = UUID()
        let scope = ToDoDataScope(resolvedAccountID: nil)

        #expect(scope.includes(ownerUserID: nil))
      #expect(!scope.includes(ownerUserID: accountID))
   }

   @Test func resolvedAccountOwnershipDoesNotDependOnStorageBackend() {
      let accountID = UUID()
      let scope = ToDoDataScope(resolvedAccountID: accountID)

      #expect(scope.includes(ownerUserID: accountID))
      #expect(!scope.includes(ownerUserID: nil))
   }

   @Test func unsignedVisibilityIncludesOnlyUnsignedPersonalRows() {
      let collabID = UUID()
      let scope = ToDoVisibilityScope(ownerUserID: nil)

      #expect(scope.includes(ownerUserID: nil, collabID: nil))
      #expect(!scope.includes(ownerUserID: UUID(), collabID: nil))
      #expect(!scope.includes(ownerUserID: nil, collabID: collabID))
   }

   @Test func accountVisibilityIncludesOnlyItsPersonalRows() {
      let accountID = UUID()
      let scope = ToDoVisibilityScope(ownerUserID: accountID)

      #expect(scope.includes(ownerUserID: accountID, collabID: nil))
      #expect(!scope.includes(ownerUserID: nil, collabID: nil))
      #expect(!scope.includes(ownerUserID: UUID(), collabID: nil))
   }

   @Test func collaborationVisibilityRequiresExplicitMembership() {
      let accountID = UUID()
      let accessibleCollabID = UUID()
      let inaccessibleCollabID = UUID()
      let scope = ToDoVisibilityScope(
         ownerUserID: accountID,
         accessibleCollabIDs: [accessibleCollabID]
      )

      #expect(scope.includes(ownerUserID: UUID(), collabID: accessibleCollabID))
      #expect(!scope.includes(ownerUserID: UUID(), collabID: inaccessibleCollabID))
   }

   @Test func collaborationOwnerRemainsVisibleWhileMembershipSnapshotLoads() {
      let accountID = UUID()
      let collabID = UUID()
      let scope = ToDoVisibilityScope(ownerUserID: accountID)

      #expect(scope.includes(ownerUserID: accountID, collabID: collabID))
   }
}

@MainActor
private extension SyncMigrationDirection {
    var touchesCloudKitStore: Bool {
        sourceMode == .iCloud || destinationMode == .iCloud
    }
}
