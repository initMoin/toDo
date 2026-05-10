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
}

@MainActor
private extension SyncMigrationDirection {
    var touchesCloudKitStore: Bool {
        sourceMode == .iCloud || destinationMode == .iCloud
    }
}
