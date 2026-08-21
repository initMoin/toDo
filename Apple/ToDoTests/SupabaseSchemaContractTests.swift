import Foundation
import Testing
@testable import ToDo

@Suite("Supabase schema contract")
@MainActor
struct SupabaseSchemaContractTests {
    private struct DescribedError: Error, CustomStringConvertible {
        let description: String
    }

    @Test func todoTaskPayloadUsesDomainTaskColumn() throws {
        let payload = SupabaseSchemaContractProbe.toDoPayload(
            task: "Write spec",
            completedAt: Date(timeIntervalSinceReferenceDate: 1)
        )
        let keys = try encodedKeys(for: payload)

        #expect(keys.contains("task"))
        #expect(keys.contains("is_done"))
        #expect(keys.contains("updated_at"))
        #expect(keys.contains("completed_at"))
        #expect(keys.contains("complete_when_all_nanodos_done"))
        #expect(!keys.contains("missive"))
        #expect(!keys.contains("title"))
    }

    @Test func completionActivityMigrationAddsAndBackfillsTheColumn() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260801090000_add_todo_completion_activity.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)

        #expect(sql.contains("add column if not exists completed_at timestamptz"))
        #expect(sql.contains("set completed_at = coalesce(completed_at, updated_at)"))
        #expect(sql.contains("todos_user_completed_at_idx"))
    }

    @Test func collabToDoPayloadUsesTheCollabColumn() throws {
        let payload = SupabaseSchemaContractProbe.toDoPayload(
            task: "Review launch",
            collabID: UUID()
        )
        let keys = try encodedKeys(for: payload)

        #expect(keys.contains("collab_id"))
    }

    @Test func trashedToDoPayloadCarriesReversibleTrashState() throws {
        let payload = SupabaseSchemaContractProbe.toDoPayload(
            task: "Keep until permanently deleted",
            lifecycleState: .trashed,
            trashedAt: Date(timeIntervalSinceReferenceDate: 500)
        )
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["lifecycle_state"] as? String == "trashed")
        #expect(object["trashed_at"] != nil)
    }

    @Test func trashLifecycleMigrationExtendsTheDatabaseContract() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260717190000_add_trashed_todo_lifecycle.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)

        #expect(sql.contains("add column if not exists trashed_at timestamptz"))
        #expect(sql.contains("'active', 'done', 'archived', 'trashed'"))
        #expect(sql.contains("validate constraint todos_lifecycle_state_check"))
    }

    @Test func nanoDoTaskPayloadUsesDomainTaskColumn() throws {
        let payload = SupabaseSchemaContractProbe.nanoDoPayload(task: "Draft outline")
        let keys = try encodedKeys(for: payload)

        #expect(keys.contains("task"))
        #expect(keys.contains("updated_at"))
        #expect(!keys.contains("title"))
    }

    @Test func sharedRecordUpdatesDoNotAttemptToTransferOwnership() throws {
        let toDoKeys = try encodedKeys(
            for: SupabaseSchemaContractProbe.sharedToDoUpdatePayload(task: "Review launch")
        )
        let nanoDoKeys = try encodedKeys(
            for: SupabaseSchemaContractProbe.sharedNanoDoUpdatePayload(task: "Check screenshots")
        )

        #expect(!toDoKeys.contains("id"))
        #expect(!toDoKeys.contains("user_id"))
        #expect(!toDoKeys.contains("created_at"))
        #expect(!nanoDoKeys.contains("id"))
        #expect(!nanoDoKeys.contains("todo_id"))
        #expect(!nanoDoKeys.contains("user_id"))
        #expect(!nanoDoKeys.contains("created_at"))
    }

    @Test func sharedRecordsUseUpdateInsteadOfRLSIncompatibleUpsert() {
        let actingUserID = UUID()
        let otherUserID = UUID()

        #expect(SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: actingUserID,
            localOwnerID: actingUserID,
            actingUserID: actingUserID
        ) == .insertOrUpsert)
        #expect(SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: otherUserID,
            localOwnerID: otherUserID,
            actingUserID: actingUserID
        ) == .authorizedUpdate)
        #expect(SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: nil,
            localOwnerID: actingUserID,
            actingUserID: actingUserID
        ) == .insertOrUpsert)
        #expect(SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: nil,
            localOwnerID: nil,
            actingUserID: actingUserID
        ) == .insertOrUpsert)
        #expect(SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: nil,
            localOwnerID: otherUserID,
            actingUserID: actingUserID
        ) == .skipUnauthorizedInsert)
    }

    @Test func tagCloudIDsCannotReuseAnAccessibleTagOwnedByAnotherUser() {
        let actingUserID = UUID()
        let otherUserID = UUID()
        let localCloudID = UUID()
        let replacementCloudID = UUID()

        #expect(SupabaseTagCloudIDRepairDisposition.resolve(
            localOwnerID: actingUserID,
            activeUserID: actingUserID,
            localCloudID: localCloudID,
            remoteRecordID: localCloudID,
            remoteRecordOwnerID: otherUserID,
            matchingOwnedRecordID: nil
        ) == .assignNew)
        #expect(SupabaseTagCloudIDRepairDisposition.resolve(
            localOwnerID: actingUserID,
            activeUserID: actingUserID,
            localCloudID: localCloudID,
            remoteRecordID: localCloudID,
            remoteRecordOwnerID: otherUserID,
            matchingOwnedRecordID: replacementCloudID
        ) == .relink(replacementCloudID))
        #expect(SupabaseTagCloudIDRepairDisposition.resolve(
            localOwnerID: actingUserID,
            activeUserID: actingUserID,
            localCloudID: localCloudID,
            remoteRecordID: localCloudID,
            remoteRecordOwnerID: actingUserID,
            matchingOwnedRecordID: replacementCloudID
        ) == .retain)
    }

    @Test func hiddenTagCollisionRetriesWithFreshIDsWithoutMaskingOtherFailures() {
        #expect(SupabaseTagUploadRecoveryDisposition.resolve(
            errorDescription: "PostgrestError(code: 42501, message: new row violates row-level security policy for table \"tags\")"
        ) == .retryWithFreshIDs)
        #expect(SupabaseTagUploadRecoveryDisposition.resolve(
            errorDescription: "duplicate key value violates unique constraint tags_pkey"
        ) == .retryWithFreshIDs)
        #expect(SupabaseTagUploadRecoveryDisposition.resolve(
            errorDescription: "The operation couldn't be completed."
        ) == .propagate)
        #expect(SupabaseTagUploadRecoveryDisposition.resolve(
            errorDescription: "new row violates row-level security policy for table \"todos\""
        ) == .propagate)
    }

    @Test func unseenTagIDsUseInsertWhileOwnedRemoteTagsMayUpsert() {
        let activeUserID = UUID()
        #expect(
            SupabaseTagWriteDisposition.resolve(
                remoteOwnerID: activeUserID,
                actingUserID: activeUserID
            ) == .upsert
        )
        #expect(
            SupabaseTagWriteDisposition.resolve(
                remoteOwnerID: UUID(),
                actingUserID: activeUserID
            ) == .insert
        )
        #expect(
            SupabaseTagWriteDisposition.resolve(
                remoteOwnerID: nil,
                actingUserID: activeUserID
            ) == .insert
        )
    }

    @Test func nanoDoUploadRequiresAnAuthorizedParentThatWillExist() {
        #expect(SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: false,
            isParentTombstoned: false,
            parentExistsRemotely: true,
            parentWillBeInserted: false
        ) == .upload)
        #expect(SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: false,
            isParentTombstoned: false,
            parentExistsRemotely: false,
            parentWillBeInserted: true
        ) == .upload)
        #expect(SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: false,
            isParentTombstoned: false,
            parentExistsRemotely: false,
            parentWillBeInserted: false
        ) == .skipMissingParent)
    }

    @Test func nanoDoUploadNeverResurrectsTombstonedRecords() {
        #expect(SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: true,
            isParentTombstoned: false,
            parentExistsRemotely: true,
            parentWillBeInserted: false
        ) == .skipTombstonedRecord)
        #expect(SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: false,
            isParentTombstoned: true,
            parentExistsRemotely: false,
            parentWillBeInserted: true
        ) == .skipTombstonedRecord)
    }

    @Test func explicitSyncFlushQueuesUntilTheActiveAccountIsHydrated() {
        let userID = UUID()

        #expect(SupabaseLocalSyncFlushDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            hasModelContainer: true,
            hasHydratedActiveUser: false,
            isApplyingRemoteSnapshot: false
        ) == .queueUntilHydrated)
        #expect(SupabaseLocalSyncFlushDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            hasModelContainer: true,
            hasHydratedActiveUser: true,
            isApplyingRemoteSnapshot: true
        ) == .queueAfterRemoteApply)
        #expect(SupabaseLocalSyncFlushDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            hasModelContainer: true,
            hasHydratedActiveUser: true,
            isApplyingRemoteSnapshot: false
        ) == .perform)
    }

    @Test func explicitSyncFlushRejectsAStaleOrUnconfiguredAccount() {
        let userID = UUID()

        #expect(SupabaseLocalSyncFlushDisposition.resolve(
            activeUserID: UUID(),
            requestedUserID: userID,
            hasModelContainer: true,
            hasHydratedActiveUser: true,
            isApplyingRemoteSnapshot: false
        ) == .ignore)
        #expect(SupabaseLocalSyncFlushDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            hasModelContainer: false,
            hasHydratedActiveUser: true,
            isApplyingRemoteSnapshot: false
        ) == .ignore)
    }

    @Test func inFlightSyncCancelsWhenTheAccountChangesOrTaskIsCancelled() {
        let userID = UUID()

        #expect(SupabaseSyncAccountGuardDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            taskIsCancelled: false
        ) == .proceed)
        #expect(SupabaseSyncAccountGuardDisposition.resolve(
            activeUserID: UUID(),
            requestedUserID: userID,
            taskIsCancelled: false
        ) == .cancel)
        #expect(SupabaseSyncAccountGuardDisposition.resolve(
            activeUserID: userID,
            requestedUserID: userID,
            taskIsCancelled: true
        ) == .cancel)
    }

    @Test func semanticDuplicateCleanupRequiresCreationIdentity() {
        #expect(!SupabaseSchemaContractProbe.exactDuplicateKeysMatchWhenOnlyCreatedAtDiffers())
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysDifferWhenCreatedAtDiffers())
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysMatchForSameCreationIdentity())
    }

    @Test func semanticDuplicateCleanupStillProtectsDistinctSchedules() {
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysDifferForDifferentDueDates())
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysDifferForDifferentRecurrenceCadence())
    }

    @Test func presentationCanonicalizationUsesCloudIdentity() {
        let cloudID = UUID()
        let stale = ToDo(
            task: "Stale",
            updatedAt: Date(timeIntervalSinceReferenceDate: 100),
            cloudID: cloudID
        )
        let current = ToDo(
            task: "Current",
            updatedAt: Date(timeIntervalSinceReferenceDate: 200),
            cloudID: cloudID
        )

        let canonical = ToDo.canonicalToDos(from: [stale, current])

        #expect(canonical.count == 1)
        #expect(canonical.first?.task == "Current")
    }

    @Test func presentationCanonicalizationKeepsDistinctUnsyncedToDos() {
        let first = ToDo(task: "Same text")
        let second = ToDo(task: "Same text")

        #expect(ToDo.canonicalToDos(from: [first, second]).count == 2)
    }

    @Test func collabMigrationKeepsAuthorizationServerSide() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260716190000_add_collab_todos.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)

        #expect(sql.contains("add column if not exists collab_id uuid"))
        #expect(sql.contains("security definer"))
        #expect(sql.contains("todos_select_accessible"))
        #expect(sql.contains("todos_delete_creator_or_collab_owner"))
        #expect(sql.contains("Only the toDō creator can change its Collab"))
        #expect(sql.contains("user_id = (select auth.uid())"))
        #expect(sql.contains("public.is_collab_user"))
        #expect(sql.contains("public.is_collab_owner"))
        #expect(sql.contains("references public.collabs(id)"))
        #expect(sql.contains("from public.collab_users"))
    }

    @Test func collabFoundationUsesCanonicalProductVocabulary() throws {
        let migrationURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "supabase/migrations/20260716120000_add_collabs.sql")
        let sql = try String(contentsOf: migrationURL, encoding: .utf8)

        #expect(sql.contains("create table if not exists public.collabs"))
        #expect(sql.contains("create table if not exists public.collab_users"))
        #expect(sql.contains("create table if not exists public.collab_invitations"))
        #expect(sql.contains("check (role in ('owner', 'user'))"))
        #expect(sql.contains("public.send_collab_invitation"))
        #expect(sql.contains("public.remove_collab_user"))
    }

    @Test func pendingCollabSchemaDoesNotBlockPersonalSync() {
        let pendingMigration = DescribedError(
            description: "Could not find the table 'public.collabs' in the schema cache"
        )
        let authorizationFailure = DescribedError(
            description: "new row violates row-level security policy for table collabs"
        )
        let unrelatedMissingTable = DescribedError(
            description: "Could not find the table 'public.tags' in the schema cache"
        )

        #expect(SupabaseSyncService.isMissingCollaborationSchema(pendingMigration))
        #expect(!SupabaseSyncService.isMissingCollaborationSchema(authorizationFailure))
        #expect(!SupabaseSyncService.isMissingCollaborationSchema(unrelatedMissingTable))
    }

    private func encodedKeys<T: Encodable>(for payload: T) throws -> Set<String> {
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }
}
