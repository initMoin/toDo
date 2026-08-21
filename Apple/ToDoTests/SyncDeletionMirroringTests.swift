import Foundation
import SwiftData
import Testing
@testable import ToDo

@Suite("Sync deletion mirroring")
@MainActor
struct SyncDeletionMirroringTests {
   @Test func resetPolicyDeletesPersonalButNeverSharedToDos() {
      let accountID = UUID()

      #expect(ToDoDataResetService.shouldDeletePersonalToDo(
         ownerUserID: accountID,
         collabID: nil,
         accountUserID: accountID
      ))
      #expect(ToDoDataResetService.shouldDeletePersonalToDo(
         ownerUserID: nil,
         collabID: nil,
         accountUserID: accountID
      ))
      #expect(!ToDoDataResetService.shouldDeletePersonalToDo(
         ownerUserID: accountID,
         collabID: UUID(),
         accountUserID: accountID
      ))
      #expect(!ToDoDataResetService.shouldDeletePersonalToDo(
         ownerUserID: UUID(),
         collabID: nil,
         accountUserID: accountID
      ))
   }

   @Test func bulkTombstonesAreUniqueAndKeepTheLatestDeletion() throws {
      let suiteName = "SyncDeletionMirroringTests.bulk"
      let defaults = try #require(UserDefaults(suiteName: suiteName))
      defer { defaults.removePersistentDomain(forName: suiteName) }
      let userID = UUID()
      let recordID = UUID()
      let older = SyncTombstone(
         userID: userID,
         recordTable: .toDos,
         recordID: recordID,
         deletedAt: Date(timeIntervalSinceReferenceDate: 10)
      )
      let newer = SyncTombstone(
         userID: userID,
         recordTable: .toDos,
         recordID: recordID,
         deletedAt: Date(timeIntervalSinceReferenceDate: 20)
      )

      SyncTombstoneStore.recordDeletes([older, newer], userDefaults: defaults)

      let pending = SyncTombstoneStore.pendingTombstones(userDefaults: defaults)
      #expect(pending.count == 1)
      #expect(pending.first?.deletedAt == newer.deletedAt)
   }

   @Test func resetDeletesPersonalDataAndPreservesSharedAndOtherAccountData() async throws {
      let context = try makeContext()
      let suiteName = "SyncDeletionMirroringTests.reset"
      let defaults = try #require(UserDefaults(suiteName: suiteName))
      defer { defaults.removePersistentDomain(forName: suiteName) }
      let accountID = UUID()
      let personalCloudID = UUID()
      let personal = ToDo(
         task: "Personal",
         cloudID: personalCloudID,
         ownerUserID: accountID
      )
      let deviceOnly = ToDo(task: "Device only")
      let shared = ToDo(
         task: "Shared",
         cloudID: UUID(),
         ownerUserID: accountID,
         collabID: UUID()
      )
      let otherAccount = ToDo(
         task: "Other account",
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      let retainedTag = Tag(name: "release", ownerUserID: accountID)
      personal.tags = [retainedTag]
      for model in [personal, deviceOnly, shared, otherAccount] {
         context.insert(model)
      }
      context.insert(retainedTag)
      try context.save()

      let report = try await ToDoDataResetService.reset(
         toDos: [personal, deviceOnly, shared, otherAccount],
         accountUserID: accountID,
         sharedListChoice: .keep,
         collaborationService: .preview,
         in: context,
         userDefaults: defaults
      )

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
      #expect(report.deletedPersonalToDoCount == 2)
      #expect(Set(remainingToDos.map(\.task)) == Set(["Shared", "Other account"]))
      #expect(retainedTag.name == "release")
      #expect(
         SyncTombstoneStore.pendingTombstones(userDefaults: defaults)
            .contains { $0.recordID == personalCloudID && $0.recordTable == .toDos }
      )
   }

   @Test func accountDeletionPurgesLocalModelsAndTombstones() throws {
      let context = try makeContext()
      let suiteName = "SyncDeletionMirroringTests.accountDeletion"
      let defaults = try #require(UserDefaults(suiteName: suiteName))
      defer { defaults.removePersistentDomain(forName: suiteName) }

      let accountID = UUID()
      let toDo = ToDo(
         task: "Private account data",
         cloudID: UUID(),
         ownerUserID: accountID
      )
      let nanoDo = NanoDo(
         task: "Private nanoDo",
         toDo: toDo,
         cloudID: UUID(),
         ownerUserID: accountID
      )
      let conflict = SyncConflict(
         userID: accountID,
         recordID: UUID(),
         severity: .warning,
         title: "Private conflict",
         message: "Private conflict data",
         localSummary: "Local",
         syncedSummary: "Synced",
         localUpdatedAt: .now,
         syncedUpdatedAt: .now,
         syncedTask: "Private conflict",
         syncedNotes: "",
         syncedIsDone: false,
         syncedLifecycleState: .active,
         syncedReminderIntent: .soft,
         syncedDueDate: nil,
         syncedRecurrenceUnit: nil,
         syncedRecurrenceInterval: nil,
         syncedRecurrenceMode: nil,
         syncedRecurrenceCount: nil,
         syncedRecurrenceAnchorDate: nil,
         syncedRecurrenceEndDate: nil
      )
      context.insert(toDo)
      context.insert(nanoDo)
      context.insert(conflict)
      try context.save()

      SyncTombstoneStore.recordDelete(
         table: .toDos,
         recordID: toDo.cloudID,
         userID: accountID,
         userDefaults: defaults
      )

      try ToDoLocalAccountDeletionService.clearAll(
         userID: accountID,
         in: context,
         userDefaults: defaults
      )

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
      let remainingNanoDos = try context.fetch(FetchDescriptor<NanoDo>())
      let remainingConflicts = try context.fetch(FetchDescriptor<SyncConflict>())
      #expect(remainingToDos.isEmpty)
      #expect(remainingNanoDos.isEmpty)
      #expect(remainingConflicts.isEmpty)
      #expect(SyncTombstoneStore.pendingTombstones(userDefaults: defaults).isEmpty)
   }

   @Test func signOutCacheCleanupRemovesOnlyTheActiveAccountPartition() throws {
      let context = try makeContext()
      let suiteName = "SyncDeletionMirroringTests.signOutCache"
      let defaults = try #require(UserDefaults(suiteName: suiteName))
      defer { defaults.removePersistentDomain(forName: suiteName) }
      let accountA = UUID()
      let accountB = UUID()
      let accessibleCollabID = UUID()
      let unrelatedCollabID = UUID()

      let accountAToDo = ToDo(task: "Account A", cloudID: UUID(), ownerUserID: accountA)
      let accountANanoDo = NanoDo(
         task: "Account A step",
         toDo: accountAToDo,
         cloudID: UUID(),
         ownerUserID: accountA
      )
      accountAToDo.nanoDos = [accountANanoDo]
      let anonymousToDo = ToDo(task: "Unsigned")
      let anonymousNanoDo = NanoDo(task: "Unsigned step", toDo: anonymousToDo)
      anonymousToDo.nanoDos = [anonymousNanoDo]
      let accountBToDo = ToDo(task: "Account B", cloudID: UUID(), ownerUserID: accountB)
      let accountBNanoDo = NanoDo(
         task: "Account B step",
         toDo: accountBToDo,
         cloudID: UUID(),
         ownerUserID: accountB
      )
      accountBToDo.nanoDos = [accountBNanoDo]
      let accessibleSharedToDo = ToDo(
         task: "Shared with A",
         cloudID: UUID(),
         ownerUserID: accountB,
         collabID: accessibleCollabID
      )
      let unrelatedSharedToDo = ToDo(
         task: "Not shared with A",
         cloudID: UUID(),
         ownerUserID: accountB,
         collabID: unrelatedCollabID
      )
      let accountATag = Tag(name: "account-a", ownerUserID: accountA)
      let accountBTag = Tag(name: "account-b", ownerUserID: accountB)

      for toDo in [accountAToDo, anonymousToDo, accountBToDo, accessibleSharedToDo, unrelatedSharedToDo] {
         context.insert(toDo)
      }
      context.insert(accountANanoDo)
      context.insert(anonymousNanoDo)
      context.insert(accountBNanoDo)
      context.insert(accountATag)
      context.insert(accountBTag)
      try context.save()

      SyncTombstoneStore.recordDelete(
         table: .toDos,
         recordID: accountAToDo.cloudID,
         userID: accountA,
         userDefaults: defaults
      )
      SyncTombstoneStore.recordDelete(
         table: .toDos,
         recordID: accountBToDo.cloudID,
         userID: accountB,
         userDefaults: defaults
      )

      try ToDoLocalAccountCacheService.clear(
         userID: accountA,
         accessibleCollabIDs: [accessibleCollabID],
         in: context,
         userDefaults: defaults
      )

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
      let remainingTags = try fetchAll(type(of: accountATag), from: context)
      let remainingNanoDos = try context.fetch(FetchDescriptor<NanoDo>())
      #expect(Set(remainingToDos.map(\.task)) == Set(["Unsigned", "Account B", "Not shared with A"]))
      #expect(Set(remainingTags.map { $0.name }) == Set(["account-b"]))
      #expect(Set(remainingNanoDos.map(\.task)) == Set(["Unsigned step", "Account B step"]))
      #expect(SyncTombstoneStore.pendingTombstones(for: accountA, userDefaults: defaults).isEmpty)
      #expect(SyncTombstoneStore.pendingTombstones(for: accountB, userDefaults: defaults).count == 1)
   }

   @Test func syncedDeleteRemovesMatchingDeviceOnlyCounterpartByDefault() throws {
      let context = try makeContext()
      let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests.removeDefault"))
      defaults.set(true, forKey: AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly)
      defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests.removeDefault") }

      let createdAt = Date(timeIntervalSinceReferenceDate: 10)
      let localToDo = ToDo(task: "Budget", createdAt: createdAt)
      let syncedToDo = ToDo(
         task: "Budget",
         createdAt: createdAt,
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      context.insert(localToDo)
      context.insert(syncedToDo)

      SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
         for: syncedToDo,
         in: context,
         userDefaults: defaults
      )
      context.delete(syncedToDo)
      try context.save()

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
      #expect(remainingToDos.isEmpty)
   }

   @Test func syncedDeleteKeepsDeviceOnlyCounterpartWhenPreferenceIsOff() throws {
      let context = try makeContext()
      let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests"))
      defaults.set(false, forKey: AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly)
      defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests") }

      let createdAt = Date(timeIntervalSinceReferenceDate: 20)
      let localToDo = ToDo(task: "Budget", createdAt: createdAt)
      let syncedToDo = ToDo(
         task: "Budget",
         createdAt: createdAt,
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      context.insert(localToDo)
      context.insert(syncedToDo)

      SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
         for: syncedToDo,
         in: context,
         userDefaults: defaults
      )
      context.delete(syncedToDo)
      try context.save()

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
      #expect(remainingToDos.map(\.task) == ["Budget"])
      #expect(remainingToDos.first?.ownerUserID == nil)
   }

   @Test func syncedDeleteMovesToTrashInsteadOfPermanentRemoval() throws {
      let context = try makeContext()
      let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests.trash"))
      defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests.trash") }
      let createdAt = Date(timeIntervalSinceReferenceDate: 10)

      let syncedToDo = ToDo(
         task: "Budget",
         createdAt: createdAt,
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      context.insert(syncedToDo)

      syncedToDo.trashedAt = Date()
      syncedToDo.transition(to: .trashed)

      SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
         for: syncedToDo,
         in: context,
         recordsSyncTombstone: false,
         userDefaults: defaults
      )

      try context.save()

      let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())

      #expect(remainingToDos.count == 1)
      #expect(remainingToDos.first?.lifecycleState == .trashed)
      #expect(remainingToDos.first?.trashedAt != nil)
      #expect(SyncTombstoneStore.pendingTombstones(userDefaults: defaults).isEmpty)
   }

   @Test func sharedDeleteAttributesTombstoneToActingUser() throws {
      let context = try makeContext()
      let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests.sharedActor"))
      defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests.sharedActor") }
      let ownerUserID = UUID()
      let actingUserID = UUID()
      let collabID = UUID()
      let cloudID = UUID()
      let syncedToDo = ToDo(
         task: "Shared",
         cloudID: cloudID,
         ownerUserID: ownerUserID,
         collabID: collabID
      )
      context.insert(syncedToDo)

      SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
         for: syncedToDo,
         in: context,
         actingUserID: actingUserID,
         userDefaults: defaults
      )

      let tombstone = try #require(
         SyncTombstoneStore.pendingTombstones(userDefaults: defaults).first
      )
      #expect(tombstone.userID == actingUserID)
      #expect(tombstone.collabID == collabID)
      #expect(tombstone.recordID == cloudID)
   }

   @Test func applyingRemoteDeleteDoesNotQueueAnotherTombstone() throws {
      let context = try makeContext()
      let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests.remote"))
      defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests.remote") }
      let syncedToDo = ToDo(
         task: "Remote delete",
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      context.insert(syncedToDo)

      SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
         for: syncedToDo,
         in: context,
         recordsSyncTombstone: false,
         userDefaults: defaults
      )

      #expect(SyncTombstoneStore.pendingTombstones(userDefaults: defaults).isEmpty)
   }

   private func makeContext() throws -> ModelContext {
      let configuration = ModelConfiguration(
         UUID().uuidString,
         isStoredInMemoryOnly: true,
         cloudKitDatabase: .none
      )
      let container = try ModelContainer(
         for: ToDo.self,
         Tag.self,
         NanoDo.self,
         SyncConflict.self,
         configurations: configuration
      )
      return ModelContext(container)
   }

   private func fetchAll<Model: PersistentModel>(
      _ type: Model.Type,
      from context: ModelContext
   ) throws -> [Model] {
      try context.fetch(FetchDescriptor<Model>())
   }
}
