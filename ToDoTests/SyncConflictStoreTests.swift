import Foundation
import SwiftData
import Testing
@testable import ToDo

@Suite("Sync conflict handling")
@MainActor
struct SyncConflictStoreTests {
    @Test func remoteNewerAndLocalUnchangedAppliesRemoteDecisionRule() {
        #expect(SupabaseSchemaContractProbe.remoteNewerThanUnchangedLocalShouldApply())
    }

    @Test func localNewerAndRemoteUnchangedKeepsLocalDecisionRule() {
        #expect(SupabaseSchemaContractProbe.localNewerThanUnchangedRemoteShouldUpload())
    }

    @Test func bothLocalAndRemoteChangedCreatesReviewDecisionRule() {
        #expect(SupabaseSchemaContractProbe.twoSidedToDoConflictShouldBeDetected())
    }

    @Test func recordToDoConflictCreatesSingleUnresolvedReview() throws {
        let context = try makeContext()
        let userID = UUID()
        let recordID = UUID()
        let toDo = syncedToDo(recordID: recordID, userID: userID)
        context.insert(toDo)

        let didRecordFirstConflict = SyncConflictStore.recordToDoConflict(
            localToDo: toDo,
            syncedRecord: syncedRecord(),
            userID: userID,
            in: context
        )
        let didRecordSecondConflict = SyncConflictStore.recordToDoConflict(
            localToDo: toDo,
            syncedRecord: syncedRecord(),
            userID: userID,
            in: context
        )

        let conflicts = SyncConflictStore.unresolvedConflicts(in: context, userID: userID)
        #expect(didRecordFirstConflict)
        #expect(!didRecordSecondConflict)
        #expect(conflicts.count == 1)
        #expect(conflicts.first?.title == "Sync Needs Review")
        #expect(conflicts.first?.recordID == recordID)
    }

    @Test func keepDeviceVersionMarksConflictResolvedAndUpdatesLocalTimestamp() throws {
        let context = try makeContext()
        let userID = UUID()
        let recordID = UUID()
        let localUpdatedAt = Date(timeIntervalSinceReferenceDate: 200)
        let toDo = syncedToDo(recordID: recordID, userID: userID, updatedAt: localUpdatedAt)
        context.insert(toDo)
        try context.save()

        try makeConflict(for: toDo, userID: userID, in: context)
        let conflict = try #require(SyncConflictStore.unresolvedConflict(recordID: recordID, userID: userID, in: context))

        try SyncConflictStore.resolve(conflict, resolution: .keepDeviceVersion, toDos: [toDo], in: context)

        #expect(conflict.isResolved)
        #expect(toDo.task == "Device version")
        #expect(toDo.syncUpdatedAt >= localUpdatedAt)
    }

    @Test func useSyncedVersionReplacesLocalFieldsAndMarksSyncedTimestamp() throws {
        let context = try makeContext()
        let userID = UUID()
        let recordID = UUID()
        let toDo = syncedToDo(recordID: recordID, userID: userID)
        context.insert(toDo)
        try context.save()

        let syncedUpdatedAt = try makeConflict(for: toDo, userID: userID, in: context)
        let conflict = try #require(SyncConflictStore.unresolvedConflict(recordID: recordID, userID: userID, in: context))

        try SyncConflictStore.resolve(conflict, resolution: .useSyncedVersion, toDos: [toDo], in: context)

        #expect(conflict.isResolved)
        #expect(toDo.task == "Synced version")
        #expect(toDo.notes == "Synced notes")
        #expect(toDo.isDone)
        #expect(toDo.lifecycleState == .done)
        #expect(toDo.reminderIntent == .timeSensitive)
        #expect(toDo.dueDate == Date(timeIntervalSinceReferenceDate: 500))
        #expect(toDo.recurrenceUnit == .weeks)
        #expect(toDo.recurrenceInterval == 2)
        #expect(toDo.recurrenceMode == .finite)
        #expect(toDo.recurrenceCount == 3)
        #expect(toDo.lastSyncedUpdatedAt == syncedUpdatedAt)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: ToDo.self,
            Tag.self,
            NanoDo.self,
            SyncConflict.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func syncedToDo(
        recordID: UUID,
        userID: UUID,
        updatedAt: Date = Date(timeIntervalSinceReferenceDate: 200)
    ) -> ToDo {
        let toDo = ToDo(
            task: "Device version",
            notes: "Device notes",
            createdAt: Date(timeIntervalSinceReferenceDate: 100),
            updatedAt: updatedAt,
            cloudID: recordID,
            ownerUserID: userID
        )
        toDo.lastSyncedUpdatedAt = Date(timeIntervalSinceReferenceDate: 150)
        return toDo
    }

    @discardableResult
    private func makeConflict(
        for toDo: ToDo,
        userID: UUID,
        in context: ModelContext
    ) throws -> Date {
        let syncedUpdatedAt = Date(timeIntervalSinceReferenceDate: 400)
        let didRecordConflict = SyncConflictStore.recordToDoConflict(
            localToDo: toDo,
            syncedRecord: syncedRecord(updatedAt: syncedUpdatedAt),
            userID: userID,
            in: context
        )
        #expect(didRecordConflict)
        try context.save()
        return syncedUpdatedAt
    }

    private func syncedRecord(
        updatedAt: Date = Date(timeIntervalSinceReferenceDate: 400)
    ) -> SupabaseSyncedToDoConflictRecord {
        SupabaseSyncedToDoConflictRecord(
            task: "Synced version",
            notes: "Synced notes",
            isDone: true,
            updatedAt: updatedAt,
            lifecycleState: .done,
            reminderIntent: .timeSensitive,
            dueDate: Date(timeIntervalSinceReferenceDate: 500),
            recurrenceUnit: .weeks,
            recurrenceInterval: 2,
            recurrenceMode: .finite,
            recurrenceCount: 3,
            recurrenceAnchorDate: Date(timeIntervalSinceReferenceDate: 500),
            recurrenceEndDate: Date(timeIntervalSinceReferenceDate: 900)
        )
    }
}
