import Foundation
import SwiftData
import Supabase

private struct SupabaseTagRecord: Codable {
   let id: UUID
   let userID: UUID
   let name: String
   let isDefault: Bool
   let createdAt: Date?
   let updatedAt: Date?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case name
      case isDefault = "is_default"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct SupabaseToDoRecord: Codable {
   let id: UUID
   let userID: UUID
   let collabID: UUID?
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date?
   let updatedAt: Date?
   let completedAt: Date?
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Date?
   let dueTimeZone: String?
   let isRecurring: Bool?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Date?
   let recurrenceEndAt: Date?
   let completeWhenAllNanoDosDone: Bool?
   let sortPosition: Double?
   let trashedAt: Date?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case collabID = "collab_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
      case completedAt = "completed_at"
      case lifecycleState = "lifecycle_state"
      case reminderIntent = "reminder_intent"
      case dueAt = "due_at"
      case dueTimeZone = "due_time_zone"
      case isRecurring = "is_recurring"
      case recurrenceUnit = "recurrence_unit"
      case recurrenceInterval = "recurrence_interval"
      case recurrenceMode = "recurrence_mode"
      case recurrenceCount = "recurrence_count"
      case recurrenceAnchorAt = "recurrence_anchor_at"
      case recurrenceEndAt = "recurrence_end_at"
      case completeWhenAllNanoDosDone = "complete_when_all_nanodos_done"
      case sortPosition = "sort_position"
      case trashedAt = "trashed_at"
   }
}

private struct SupabaseNanoDoRecord: Codable {
   let id: UUID
   let todoID: UUID
   let userID: UUID
   let task: String
   let isDone: Bool
   let tagID: UUID?
   let dueAt: Date?
   let createdAt: Date?
   let updatedAt: Date?

   enum CodingKeys: String, CodingKey {
      case id
      case todoID = "todo_id"
      case userID = "user_id"
      case task
      case isDone = "is_done"
      case tagID = "tag_id"
      case dueAt = "due_at"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct SupabaseToDoTagRecord: Codable, Hashable {
   let todoID: UUID
   let tagID: UUID
   let createdAt: Date?

   enum CodingKeys: String, CodingKey {
      case todoID = "todo_id"
      case tagID = "tag_id"
      case createdAt = "created_at"
   }
}

private struct SupabaseCollabIDRecord: Decodable {
   let id: UUID
}

private struct SupabaseTombstoneRecord: Codable, Hashable {
   let userID: UUID
   let collabID: UUID?
   let recordTable: String
   let recordID: UUID
   let deletedAt: Date

   enum CodingKeys: String, CodingKey {
      case userID = "user_id"
      case collabID = "collab_id"
      case recordTable = "record_table"
      case recordID = "record_id"
      case deletedAt = "deleted_at"
   }
}

private struct SupabaseTagUpsertPayload: Encodable {
   let id: UUID
   let userID: UUID
   let name: String
   let isDefault: Bool
   let createdAt: Date
   let updatedAt: Date

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case name
      case isDefault = "is_default"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct SupabaseToDoUpsertPayload: Encodable {
   let id: UUID
   let userID: UUID
   let collabID: UUID?
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date
   let updatedAt: Date
   let completedAt: Date?
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Date?
   let dueTimeZone: String?
   let isRecurring: Bool
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Date?
   let recurrenceEndAt: Date?
   let completeWhenAllNanoDosDone: Bool
   let sortPosition: Double?
   let trashedAt: Date?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case collabID = "collab_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
      case completedAt = "completed_at"
      case lifecycleState = "lifecycle_state"
      case reminderIntent = "reminder_intent"
      case dueAt = "due_at"
      case dueTimeZone = "due_time_zone"
      case isRecurring = "is_recurring"
      case recurrenceUnit = "recurrence_unit"
      case recurrenceInterval = "recurrence_interval"
      case recurrenceMode = "recurrence_mode"
      case recurrenceCount = "recurrence_count"
      case recurrenceAnchorAt = "recurrence_anchor_at"
      case recurrenceEndAt = "recurrence_end_at"
      case completeWhenAllNanoDosDone = "complete_when_all_nanodos_done"
      case sortPosition = "sort_position"
      case trashedAt = "trashed_at"
   }
}

private struct SupabaseToDoUpdatePayload: Encodable {
   let collabID: UUID?
   let task: String
   let notes: String
   let isDone: Bool
   let updatedAt: Date
   let completedAt: Date?
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Date?
   let dueTimeZone: String?
   let isRecurring: Bool
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Date?
   let recurrenceEndAt: Date?
   let completeWhenAllNanoDosDone: Bool
   let sortPosition: Double?
   let trashedAt: Date?

   init(_ payload: SupabaseToDoUpsertPayload) {
      collabID = payload.collabID
      task = payload.task
      notes = payload.notes
      isDone = payload.isDone
      updatedAt = payload.updatedAt
      completedAt = payload.completedAt
      lifecycleState = payload.lifecycleState
      reminderIntent = payload.reminderIntent
      dueAt = payload.dueAt
      dueTimeZone = payload.dueTimeZone
      isRecurring = payload.isRecurring
      recurrenceUnit = payload.recurrenceUnit
      recurrenceInterval = payload.recurrenceInterval
      recurrenceMode = payload.recurrenceMode
      recurrenceCount = payload.recurrenceCount
      recurrenceAnchorAt = payload.recurrenceAnchorAt
      recurrenceEndAt = payload.recurrenceEndAt
      completeWhenAllNanoDosDone = payload.completeWhenAllNanoDosDone
      sortPosition = payload.sortPosition
      trashedAt = payload.trashedAt
   }

   enum CodingKeys: String, CodingKey {
      case collabID = "collab_id"
      case task
      case notes
      case isDone = "is_done"
      case updatedAt = "updated_at"
      case completedAt = "completed_at"
      case lifecycleState = "lifecycle_state"
      case reminderIntent = "reminder_intent"
      case dueAt = "due_at"
      case dueTimeZone = "due_time_zone"
      case isRecurring = "is_recurring"
      case recurrenceUnit = "recurrence_unit"
      case recurrenceInterval = "recurrence_interval"
      case recurrenceMode = "recurrence_mode"
      case recurrenceCount = "recurrence_count"
      case recurrenceAnchorAt = "recurrence_anchor_at"
      case recurrenceEndAt = "recurrence_end_at"
      case completeWhenAllNanoDosDone = "complete_when_all_nanodos_done"
      case sortPosition = "sort_position"
      case trashedAt = "trashed_at"
   }
}

private struct SupabaseNanoDoUpsertPayload: Encodable {
   let id: UUID
   let todoID: UUID
   let userID: UUID
   let task: String
   let isDone: Bool
   let tagID: UUID?
   let dueAt: Date?
   let createdAt: Date
   let updatedAt: Date

   enum CodingKeys: String, CodingKey {
      case id
      case todoID = "todo_id"
      case userID = "user_id"
      case task
      case isDone = "is_done"
      case tagID = "tag_id"
      case dueAt = "due_at"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
   }
}

private struct SupabaseNanoDoUpdatePayload: Encodable {
   let task: String
   let isDone: Bool
   let tagID: UUID?
   let dueAt: Date?
   let updatedAt: Date

   init(_ payload: SupabaseNanoDoUpsertPayload) {
      task = payload.task
      isDone = payload.isDone
      tagID = payload.tagID
      dueAt = payload.dueAt
      updatedAt = payload.updatedAt
   }

   enum CodingKeys: String, CodingKey {
      case task
      case isDone = "is_done"
      case tagID = "tag_id"
      case dueAt = "due_at"
      case updatedAt = "updated_at"
   }
}

enum SupabaseSyncWriteStrategy: Equatable {
   case insertOrUpsert
   case authorizedUpdate
   case skipUnauthorizedInsert

   static func resolve(
      remoteOwnerID: UUID?,
      localOwnerID: UUID?,
      actingUserID: UUID
   ) -> Self {
      if let remoteOwnerID {
         return remoteOwnerID == actingUserID ? .insertOrUpsert : .authorizedUpdate
      }
      guard let localOwnerID else {
         // Older local records predate explicit ownership and inherit the active account on first upload.
         return .insertOrUpsert
      }
      return localOwnerID == actingUserID ? .insertOrUpsert : .skipUnauthorizedInsert
   }
}

/// Decides whether a local tag cloud ID can be reused without crossing an
/// ownership boundary. Accessible shared tags may be present in the remote
/// snapshot, so an ID match alone is not sufficient for an owned upsert.
enum SupabaseTagCloudIDRepairDisposition: Equatable {
   case retain
   case relink(UUID)
   case assignNew

   static func resolve(
      localOwnerID: UUID?,
      activeUserID: UUID,
      localCloudID: UUID?,
      remoteRecordID: UUID?,
      remoteRecordOwnerID: UUID?,
      matchingOwnedRecordID: UUID?
   ) -> Self {
      guard localOwnerID == activeUserID else { return .retain }

      if let localCloudID,
         localCloudID == remoteRecordID,
         remoteRecordOwnerID == activeUserID {
         return .retain
      }

      if let matchingOwnedRecordID {
         return .relink(matchingOwnedRecordID)
      }

      return .assignNew
   }
}

enum SupabaseTagUploadRecoveryDisposition: Equatable {
   case retryWithFreshIDs
   case propagate

   static func resolve(errorDescription: String) -> Self {
      let normalizedDescription = errorDescription.lowercased()
      let isTagRLSFailure = normalizedDescription.contains("row-level security")
         && normalizedDescription.contains("table \"tags\"")
      let isTagIDConflict = normalizedDescription.contains("duplicate key")
         && normalizedDescription.contains("tags")
      guard isTagRLSFailure || isTagIDConflict else {
         return .propagate
      }

      return .retryWithFreshIDs
   }
}

enum SupabaseTagWriteDisposition: Equatable {
   case insert
   case upsert

   static func resolve(remoteOwnerID: UUID?, actingUserID: UUID) -> Self {
      remoteOwnerID == actingUserID ? .upsert : .insert
   }
}

enum SupabaseNanoDoUploadDisposition: Equatable {
   case upload
   case skipTombstonedRecord
   case skipMissingParent

   static func resolve(
      isNanoDoTombstoned: Bool,
      isParentTombstoned: Bool,
      parentExistsRemotely: Bool,
      parentWillBeInserted: Bool
   ) -> Self {
      guard !isNanoDoTombstoned, !isParentTombstoned else {
         return .skipTombstonedRecord
      }
      guard parentExistsRemotely || parentWillBeInserted else {
         return .skipMissingParent
      }
      return .upload
   }
}

enum SupabaseLocalSyncFlushDisposition: Equatable {
   case ignore
   case queueUntilHydrated
   case queueAfterRemoteApply
   case perform

   static func resolve(
      activeUserID: UUID?,
      requestedUserID: UUID,
      hasModelContainer: Bool,
      hasHydratedActiveUser: Bool,
      isApplyingRemoteSnapshot: Bool
   ) -> Self {
      guard activeUserID == requestedUserID, hasModelContainer else { return .ignore }
      guard hasHydratedActiveUser else { return .queueUntilHydrated }
      guard !isApplyingRemoteSnapshot else { return .queueAfterRemoteApply }
      return .perform
   }
}

enum SupabaseSyncAccountGuardDisposition: Equatable {
   case proceed
   case cancel

   static func resolve(
      activeUserID: UUID?,
      requestedUserID: UUID,
      taskIsCancelled: Bool
   ) -> Self {
      guard !taskIsCancelled, activeUserID == requestedUserID else { return .cancel }
      return .proceed
   }
}

private struct SupabaseToDoTagUpsertPayload: Encodable, Hashable {
   let todoID: UUID
   let tagID: UUID

   enum CodingKeys: String, CodingKey {
      case todoID = "todo_id"
      case tagID = "tag_id"
   }
}

private struct SupabaseTombstoneUpsertPayload: Encodable, Hashable {
   let userID: UUID
   let collabID: UUID?
   let recordTable: String
   let recordID: UUID
   let deletedAt: Date

   init(_ tombstone: SyncTombstone) {
      self.userID = tombstone.userID
      self.collabID = tombstone.collabID
      self.recordTable = tombstone.recordTable.rawValue
      self.recordID = tombstone.recordID
      self.deletedAt = tombstone.deletedAt
   }

   init(
      userID: UUID,
      collabID: UUID? = nil,
      recordTable: SyncRecordTable,
      recordID: UUID,
      deletedAt: Date = .now
   ) {
      self.userID = userID
      self.collabID = collabID
      self.recordTable = recordTable.rawValue
      self.recordID = recordID
      self.deletedAt = deletedAt
   }

   enum CodingKeys: String, CodingKey {
      case userID = "user_id"
      case collabID = "collab_id"
      case recordTable = "record_table"
      case recordID = "record_id"
      case deletedAt = "deleted_at"
   }
}

#if DEBUG
enum SupabaseSchemaContractProbe {
   static func toDoPayload(
      task: String,
      collabID: UUID? = nil,
      lifecycleState: ToDoState = .active,
      trashedAt: Date? = nil,
      completedAt: Date? = nil
   ) -> some Encodable {
      SupabaseToDoUpsertPayload(
         id: UUID(),
         userID: UUID(),
         collabID: collabID,
         task: task,
         notes: "",
         isDone: false,
         createdAt: Date(timeIntervalSinceReferenceDate: 0),
         updatedAt: Date(timeIntervalSinceReferenceDate: 0),
         completedAt: completedAt,
         lifecycleState: lifecycleState.rawValue,
         reminderIntent: ToDoReminderIntent.soft.rawValue,
         dueAt: nil,
         dueTimeZone: nil,
         isRecurring: false,
         recurrenceUnit: nil,
         recurrenceInterval: nil,
         recurrenceMode: nil,
         recurrenceCount: nil,
         recurrenceAnchorAt: nil,
         recurrenceEndAt: nil,
         completeWhenAllNanoDosDone: false,
         sortPosition: nil,
         trashedAt: trashedAt
      )
   }

   static func nanoDoPayload(task: String) -> some Encodable {
      SupabaseNanoDoUpsertPayload(
         id: UUID(),
         todoID: UUID(),
         userID: UUID(),
         task: task,
         isDone: false,
         tagID: nil,
         dueAt: nil,
         createdAt: Date(timeIntervalSinceReferenceDate: 0),
         updatedAt: Date(timeIntervalSinceReferenceDate: 0)
      )
   }

   static func sharedToDoUpdatePayload(task: String) -> some Encodable {
      SupabaseToDoUpdatePayload(
         SupabaseToDoUpsertPayload(
            id: UUID(),
            userID: UUID(),
            collabID: UUID(),
            task: task,
            notes: "",
            isDone: false,
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            updatedAt: Date(timeIntervalSinceReferenceDate: 1),
            completedAt: nil,
            lifecycleState: ToDoState.active.rawValue,
            reminderIntent: ToDoReminderIntent.soft.rawValue,
            dueAt: nil,
            dueTimeZone: nil,
            isRecurring: false,
            recurrenceUnit: nil,
            recurrenceInterval: nil,
            recurrenceMode: nil,
            recurrenceCount: nil,
            recurrenceAnchorAt: nil,
            recurrenceEndAt: nil,
            completeWhenAllNanoDosDone: false,
            sortPosition: nil,
            trashedAt: nil
         )
      )
   }

   static func sharedNanoDoUpdatePayload(task: String) -> some Encodable {
      SupabaseNanoDoUpdatePayload(
         SupabaseNanoDoUpsertPayload(
            id: UUID(),
            todoID: UUID(),
            userID: UUID(),
            task: task,
            isDone: false,
            tagID: nil,
            dueAt: nil,
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            updatedAt: Date(timeIntervalSinceReferenceDate: 1)
         )
      )
   }

   static func exactDuplicateKeysMatchWhenOnlyCreatedAtDiffers() -> Bool {
      let first = ToDoDuplicateKey(
         task: "Test1",
         notes: "",
         isDone: false,
         lifecycleState: ToDoState.active.rawValue,
         reminderIntent: ToDoReminderIntent.soft.rawValue,
         createdAt: 100,
         dueAt: nil,
         recurrenceUnit: nil,
         recurrenceInterval: nil,
         recurrenceMode: nil,
         recurrenceCount: nil,
         recurrenceAnchorAt: nil,
         recurrenceEndAt: nil
      )
      let second = ToDoDuplicateKey(
         task: "Test1",
         notes: "",
         isDone: false,
         lifecycleState: ToDoState.active.rawValue,
         reminderIntent: ToDoReminderIntent.soft.rawValue,
         createdAt: 200,
         dueAt: nil,
         recurrenceUnit: nil,
         recurrenceInterval: nil,
         recurrenceMode: nil,
         recurrenceCount: nil,
         recurrenceAnchorAt: nil,
         recurrenceEndAt: nil
      )

      return first == second
   }

   static func semanticDuplicateKeysDifferWhenCreatedAtDiffers() -> Bool {
      semanticKey(task: "Test1", createdAt: 100, dueAt: nil, recurrenceInterval: nil)
      != semanticKey(task: "Test1", createdAt: 200, dueAt: nil, recurrenceInterval: nil)
   }

   static func semanticDuplicateKeysMatchForSameCreationIdentity() -> Bool {
      semanticKey(task: "Test1", createdAt: 100, dueAt: nil, recurrenceInterval: nil)
      == semanticKey(task: "Test1", createdAt: 100, dueAt: nil, recurrenceInterval: nil)
   }

   static func semanticDuplicateKeysDifferForDifferentDueDates() -> Bool {
      semanticKey(task: "Test1", dueAt: 100, recurrenceInterval: nil)
      != semanticKey(task: "Test1", dueAt: 200, recurrenceInterval: nil)
   }

   static func semanticDuplicateKeysDifferForDifferentRecurrenceCadence() -> Bool {
      semanticKey(task: "Test1", dueAt: 100, recurrenceInterval: 1)
      != semanticKey(task: "Test1", dueAt: 100, recurrenceInterval: 2)
   }

   static func remoteNewerThanUnchangedLocalShouldApply() -> Bool {
      shouldApplyRemote(
         localUpdatedAt: Date(timeIntervalSinceReferenceDate: 100),
         remoteCreatedAt: Date(timeIntervalSinceReferenceDate: 100),
         remoteUpdatedAt: Date(timeIntervalSinceReferenceDate: 200)
      )
   }

   static func localNewerThanUnchangedRemoteShouldUpload() -> Bool {
      shouldUploadLocal(
         localUpdatedAt: Date(timeIntervalSinceReferenceDate: 200),
         remoteCreatedAt: Date(timeIntervalSinceReferenceDate: 100),
         remoteUpdatedAt: Date(timeIntervalSinceReferenceDate: 100)
      )
   }

   static func twoSidedToDoConflictShouldBeDetected() -> Bool {
      let base = Date(timeIntervalSinceReferenceDate: 100)
      let localToDo = ToDo(
         task: "Local edit",
         createdAt: Date(timeIntervalSinceReferenceDate: 50),
         updatedAt: Date(timeIntervalSinceReferenceDate: 200),
         cloudID: UUID(),
         ownerUserID: UUID()
      )
      localToDo.lastSyncedUpdatedAt = base

      return hasTwoSidedToDoConflict(
         localToDo: localToDo,
         remoteTimestamp: Date(timeIntervalSinceReferenceDate: 300)
      )
   }

   private static func remoteTimestamp(createdAt: Date?, updatedAt: Date?) -> Date {
      updatedAt ?? createdAt ?? .distantPast
   }

   private static func remoteToDoStateSummary(_ records: [SupabaseToDoRecord]) -> String {
      let counts = Dictionary(grouping: records, by: \.lifecycleState)
         .mapValues(\.count)

      return ToDoState.allCases
         .map { "\($0.rawValue)=\(counts[$0.rawValue, default: 0])" }
         .joined(separator: ",")
   }

   private static func shouldApplyRemote(localUpdatedAt: Date, remoteCreatedAt: Date?, remoteUpdatedAt: Date?) -> Bool {
      remoteTimestamp(createdAt: remoteCreatedAt, updatedAt: remoteUpdatedAt) > localUpdatedAt
   }

   private static func shouldUploadLocal(localUpdatedAt: Date, remoteCreatedAt: Date?, remoteUpdatedAt: Date?) -> Bool {
      localUpdatedAt > remoteTimestamp(createdAt: remoteCreatedAt, updatedAt: remoteUpdatedAt)
   }

   private static func hasTwoSidedToDoConflict(localToDo: ToDo, remoteTimestamp: Date) -> Bool {
      let baseTimestamp = localToDo.lastSyncedUpdatedAt ?? localToDo.createdAt
      let localChangedSinceBase = localToDo.updatedAt != nil && localToDo.syncUpdatedAt > baseTimestamp
      let remoteChangedSinceBase = remoteTimestamp > baseTimestamp
      return localChangedSinceBase
      && remoteChangedSinceBase
      && abs(localToDo.syncUpdatedAt.timeIntervalSince(remoteTimestamp)) > 0.001
   }

   private static func semanticKey(
      task: String,
      createdAt: Int64? = 100,
      dueAt: Int64?,
      recurrenceInterval: Int?
   ) -> ToDoSemanticDuplicateKey {
      ToDoSemanticDuplicateKey(
         collabID: nil,
         task: task,
         notes: "",
         isDone: false,
         lifecycleState: ToDoState.active.rawValue,
         reminderIntent: ToDoReminderIntent.soft.rawValue,
         createdAt: createdAt,
         dueAt: dueAt,
         recurrenceUnit: recurrenceInterval == nil ? nil : ToDoRecurrenceUnit.days.rawValue,
         recurrenceInterval: recurrenceInterval,
         recurrenceMode: recurrenceInterval == nil ? nil : ToDoRecurrenceMode.continuous.rawValue,
         recurrenceCount: nil,
         recurrenceAnchorAt: dueAt,
         recurrenceEndAt: nil
      )
   }
}
#endif

private struct SupabaseRemoteSnapshot {
   let tags: [SupabaseTagRecord]
   let toDos: [SupabaseToDoRecord]
   let nanoDos: [SupabaseNanoDoRecord]
   let toDoTags: [SupabaseToDoTagRecord]
   let tombstones: [SupabaseTombstoneRecord]

   var isEmpty: Bool {
      tags.isEmpty && toDos.isEmpty && nanoDos.isEmpty && toDoTags.isEmpty && tombstones.isEmpty
   }

   func tombstonedIDs(for table: SyncRecordTable) -> Set<UUID> {
      Set(tombstones.filter { $0.recordTable == table.rawValue }.map(\.recordID))
   }
}

private struct LocalSnapshot {
   let tags: [Tag]
   let toDos: [ToDo]
   let nanoDos: [NanoDo]
   let conflicts: [SyncConflict]

   static var empty: LocalSnapshot {
      LocalSnapshot(tags: [], toDos: [], nanoDos: [], conflicts: [])
   }

   var hasContent: Bool {
      tags.isEmpty == false || toDos.isEmpty == false || nanoDos.isEmpty == false
   }
}

private struct LocalUploadResult {
   let uploadedToDoIDs: Set<UUID>
}

private struct RemoteApplyResult {
   let appliedToDoCount: Int
   var deletedToDoCount: Int

   var changedToDoCount: Int {
      appliedToDoCount + deletedToDoCount
   }
}

private struct ToDoDuplicateKey: Hashable {
   let task: String
   let notes: String
   let isDone: Bool
   let lifecycleState: String
   let reminderIntent: String
   let createdAt: Int64?
   let dueAt: Int64?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Int64?
   let recurrenceEndAt: Int64?
}

private struct ToDoSemanticDuplicateKey: Hashable {
   let collabID: UUID?
   let task: String
   let notes: String
   let isDone: Bool
   let lifecycleState: String
   let reminderIntent: String
   let createdAt: Int64?
   let dueAt: Int64?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Int64?
   let recurrenceEndAt: Int64?
}

private struct TagIdentityKey: Hashable {
   let ownerUserID: UUID
   let normalizedName: String
}

@MainActor
final class SupabaseSyncService {
   static let shared = SupabaseSyncService()

#if DEBUG
   private static let logsRealtimeDiagnostics = false
#endif

   private let supabase = SupabaseService.shared
   private var modelContainer: ModelContainer?
   private var activeUserID: UUID?
   private var accessibleCollabIDs = Set<UUID>()
   private var bootstrapTask: Task<Void, Never>?
   private var hasHydratedActiveUser = false
   private var isApplyingRemoteSnapshot = false
   private var needsLocalSyncAfterHydration = false
   private var needsLocalSyncAfterCurrentApply = false
   private var pendingLocalSyncTask: Task<Void, Never>?
   private var realtimeChannel: RealtimeChannelV2?
   private var realtimeUserID: UUID?
   private var realtimeStartTask: Task<Void, Never>?
   private var realtimeStartTaskUserID: UUID?
   private var realtimeListenerTasks: [Task<Void, Never>] = []
   private var realtimeStatusTask: Task<Void, Never>?
   private var realtimeRetryTask: Task<Void, Never>?
   private var realtimeRetryAttempt = 0
   private var debouncedRemoteRefreshTask: Task<Void, Never>?
   private var isPushingLocalSnapshot = false
   private var isRefreshingFromRemote = false
   private var needsRemoteRefreshAfterCurrent = false
   private var needsRemoteChangeFeedbackAfterCurrent = false

   private init() {}

   func configure(modelContainer: ModelContainer) {
      self.modelContainer = modelContainer
   }

   func activate(for userID: UUID) async -> Bool {
      guard modelContainer != nil else {
         Self.logSync("Supabase activate skipped: model container is not configured.")
         return false
      }
      Self.logSync("Supabase activate requested: userID=\(userID), activeUserID=\(activeUserID?.uuidString ?? "nil"), hydrated=\(hasHydratedActiveUser), bootstrapRunning=\(bootstrapTask != nil)")
      guard activeUserID != userID || !hasHydratedActiveUser else {
         await ensureRealtimeSubscription(for: userID)
         Self.logSync("Supabase activate reused hydrated user: \(userID).")
         return true
      }

      if activeUserID == userID {
         startBootstrapIfNeeded(for: userID)
         return true
      }

      return await performActivation(for: userID)
   }

   private func performActivation(for userID: UUID) async -> Bool {
      Self.logSync("Supabase activation switching active user to \(userID).")
      activeUserID = userID
      accessibleCollabIDs.removeAll()
      hasHydratedActiveUser = false
      needsLocalSyncAfterHydration = false
      needsLocalSyncAfterCurrentApply = false
      bootstrapTask?.cancel()
      bootstrapTask = nil
      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = nil
      stopRealtimeSubscription()
      startBootstrapIfNeeded(for: userID)
      return true
   }

   private func startBootstrapIfNeeded(for userID: UUID) {
      guard activeUserID == userID else {
         Self.logSync("Supabase bootstrap skipped: requested user \(userID) is not active.")
         return
      }
      guard bootstrapTask == nil || bootstrapTask?.isCancelled == true else {
         Self.logSync("Supabase bootstrap already running for user \(userID).")
         return
      }

      Self.logSync("Supabase bootstrap starting for user \(userID).")
      SyncCoordinator.shared.beginSyncActivation(phase: .activating)
      bootstrapTask = Task { @MainActor [weak self] in
         guard let self else { return }
         let didHydrate = await self.bootstrapLocalCache(for: userID)
         guard self.activeUserID == userID else { return }
         self.bootstrapTask = nil

         guard didHydrate else {
            Self.logSync("Supabase bootstrap ended without hydration for user \(userID).")
            return
         }
         Self.logSync("Supabase bootstrap hydrated user \(userID).")
         await self.startRealtimeSubscription(for: userID)

         if self.needsLocalSyncAfterHydration {
            self.needsLocalSyncAfterHydration = false
            self.scheduleLocalSync()
         } else if self.needsRemoteRefreshAfterCurrent {
            self.needsRemoteRefreshAfterCurrent = false
            self.scheduleRemoteRefresh(for: userID, delayNanoseconds: 150_000_000)
         }
      }
   }

   func deactivate() {
      activeUserID = nil
      accessibleCollabIDs.removeAll()
      bootstrapTask?.cancel()
      bootstrapTask = nil
      hasHydratedActiveUser = false
      needsLocalSyncAfterHydration = false
      needsLocalSyncAfterCurrentApply = false
      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = nil
      debouncedRemoteRefreshTask?.cancel()
      debouncedRemoteRefreshTask = nil
      stopRealtimeSubscription()
   }

   func suspendRealtime() {
      stopRealtimeSubscription()
   }

   func resumeRealtimeIfNeeded() async {
      guard let activeUserID, hasHydratedActiveUser else { return }
      await ensureRealtimeSubscription(for: activeUserID)
   }

   func scheduleLocalSync() {
      guard let activeUserID, modelContainer != nil else { return }
      guard hasHydratedActiveUser else {
         needsLocalSyncAfterHydration = true
         SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
         return
      }
      guard !isApplyingRemoteSnapshot else {
         needsLocalSyncAfterCurrentApply = true
         SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
         return
      }

      SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = Task { [weak self] in
         guard let self else { return }
         try? await Task.sleep(nanoseconds: 800_000_000)
         guard !Task.isCancelled else { return }
         _ = await self.pushLocalSnapshot(for: activeUserID)
      }
   }

   @discardableResult
   func flushLocalSync(for userID: UUID) async -> Bool {
      switch SupabaseLocalSyncFlushDisposition.resolve(
         activeUserID: activeUserID,
         requestedUserID: userID,
         hasModelContainer: modelContainer != nil,
         hasHydratedActiveUser: hasHydratedActiveUser,
         isApplyingRemoteSnapshot: isApplyingRemoteSnapshot
      ) {
      case .ignore:
         return false
      case .queueUntilHydrated:
         needsLocalSyncAfterHydration = true
         SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
      case .queueAfterRemoteApply:
         needsLocalSyncAfterCurrentApply = true
         SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
      case .perform:
         break
      }

      guard await waitForFlushReadiness(for: userID) else { return false }

      // Remote reconciliation can schedule one follow-up upload. Keep the
      // final sign-out flush bounded if malformed data repeatedly requeues it.
      for _ in 0..<3 {
         pendingLocalSyncTask?.cancel()
         pendingLocalSyncTask = nil
         guard await pushLocalSnapshot(for: userID) else { return false }
         guard pendingLocalSyncTask != nil || needsLocalSyncAfterCurrentApply else {
            return true
         }
         guard await waitForFlushReadiness(for: userID) else { return false }
      }

      return false
   }

   private func waitForFlushReadiness(for userID: UUID) async -> Bool {
      let clock = ContinuousClock()
      let deadline = clock.now.advanced(by: .seconds(30))

      while activeUserID == userID,
            (bootstrapTask != nil
             || !hasHydratedActiveUser
             || isApplyingRemoteSnapshot
             || isPushingLocalSnapshot
             || isRefreshingFromRemote) {
         guard !Task.isCancelled, clock.now < deadline else { return false }
         try? await Task.sleep(for: .milliseconds(100))
      }

      return activeUserID == userID
         && modelContainer != nil
         && hasHydratedActiveUser
         && !isApplyingRemoteSnapshot
         && !isPushingLocalSnapshot
         && !isRefreshingFromRemote
   }

   func purgeLocalAccountCache(for userID: UUID) throws {
      guard activeUserID == userID, let modelContainer else {
         throw ToDoSyncBackendError.accountCacheUnavailable
      }
      let collabIDs = accessibleCollabIDs
      let context = modelContainer.mainContext

      // Stop observation before deleting the cache so local cleanup cannot be
      // interpreted as a request to delete the user's server records.
      deactivate()
      do {
         try ToDoLocalAccountCacheService.clear(
            userID: userID,
            accessibleCollabIDs: collabIDs,
            in: context
         )
      } catch {
         context.rollback()
         throw error
      }
   }

   func refreshFromRemote(for userID: UUID, showsRemoteChangeFeedback: Bool = false) async {
      guard activeUserID == userID, modelContainer != nil else { return }
      guard hasHydratedActiveUser else {
         needsRemoteRefreshAfterCurrent = true
         needsRemoteChangeFeedbackAfterCurrent = needsRemoteChangeFeedbackAfterCurrent || showsRemoteChangeFeedback
         return
      }
      guard !isApplyingRemoteSnapshot else { return }
      guard !isPushingLocalSnapshot, !isRefreshingFromRemote else {
         needsRemoteRefreshAfterCurrent = true
         needsRemoteChangeFeedbackAfterCurrent = needsRemoteChangeFeedbackAfterCurrent || showsRemoteChangeFeedback
         return
      }

      isRefreshingFromRemote = true
      defer {
         isRefreshingFromRemote = false
         if needsRemoteRefreshAfterCurrent {
            let shouldShowFeedback = needsRemoteChangeFeedbackAfterCurrent
            needsRemoteRefreshAfterCurrent = false
            needsRemoteChangeFeedbackAfterCurrent = false
            scheduleRemoteRefresh(
               for: userID,
               delayNanoseconds: 150_000_000,
               showsRemoteChangeFeedback: shouldShowFeedback
            )
         }
      }

      await pullRemoteSnapshot(for: userID, showsRemoteChangeFeedback: showsRemoteChangeFeedback)
   }

   private func ensureRealtimeSubscription(for userID: UUID) async {
      guard realtimeChannel == nil || realtimeUserID != userID || realtimeListenerTasks.isEmpty else { return }
      await requestRealtimeSubscription(for: userID)
   }

   private func requestRealtimeSubscription(for userID: UUID, retryAttempt: Int = 0) async {
      if retryAttempt == 0,
         realtimeChannel != nil,
         realtimeUserID == userID,
         !realtimeListenerTasks.isEmpty {
         return
      }

      if let realtimeStartTask, realtimeStartTaskUserID == userID {
         await realtimeStartTask.value
         return
      }

      let task = Task { @MainActor [weak self] in
         guard let self else { return }
         await self.startRealtimeSubscription(for: userID, retryAttempt: retryAttempt)
      }
      realtimeStartTask = task
      realtimeStartTaskUserID = userID
      await task.value
      if realtimeStartTaskUserID == userID {
         realtimeStartTask = nil
         realtimeStartTaskUserID = nil
      }
   }

   private func startRealtimeSubscription(for userID: UUID, retryAttempt: Int = 0) async {
      guard activeUserID == userID else { return }
      if retryAttempt == 0 {
         realtimeRetryTask?.cancel()
         realtimeRetryAttempt = 0
      }
      realtimeRetryTask = nil
      stopRealtimeSubscription(cancelRetry: false, cancelStart: false)

      let channel = supabase.channel("todo-sync-\(userID.uuidString)-\(UUID().uuidString)")
      let streams = [
         channel.postgresChange(AnyAction.self, schema: "public", table: "todos"),
         channel.postgresChange(AnyAction.self, schema: "public", table: "tags"),
         channel.postgresChange(AnyAction.self, schema: "public", table: "nanodos"),
         channel.postgresChange(AnyAction.self, schema: "public", table: "sync_tombstones")
      ]

      do {
         await supabase.realtimeV2.connect()
         realtimeStatusTask = Task { @MainActor [weak self] in
            var hasSubscribed = false
            for await status in channel.statusChange {
               Self.logRealtime("Supabase realtime status: \(status)")
               if status == .subscribed {
                  hasSubscribed = true
               } else if status == .unsubscribed && hasSubscribed {
                  self?.scheduleRealtimeRetry(for: userID)
               }
            }
         }
         realtimeListenerTasks = streams.map { stream in
            Task { [weak self] in
               for await _ in stream {
                  Self.logRealtime("Supabase realtime event received. Refreshing toDō Sync.")
                  self?.scheduleRemoteRefresh(
                     for: userID,
                     delayNanoseconds: 150_000_000,
                     showsRemoteChangeFeedback: true
                  )
               }
               guard !Task.isCancelled else { return }
               self?.handleRealtimeStreamEnded(for: userID)
            }
         }
         try await channel.subscribeWithError()
         realtimeChannel = channel
         realtimeUserID = userID
         realtimeRetryAttempt = 0
         Self.logRealtime("Supabase realtime subscribed for toDō Sync user \(userID).")
      } catch {
         realtimeStatusTask?.cancel()
         realtimeStatusTask = nil
         realtimeListenerTasks.forEach { $0.cancel() }
         realtimeListenerTasks.removeAll()
         Task {
            await supabase.removeChannel(channel)
         }
         Self.logRealtime("Supabase realtime subscription failed: \(error)")
         scheduleRealtimeRetry(for: userID)
      }
   }

   private func stopRealtimeSubscription(cancelRetry: Bool = true, cancelStart: Bool = true) {
      if cancelStart {
         realtimeStartTask?.cancel()
         realtimeStartTask = nil
         realtimeStartTaskUserID = nil
      }
      realtimeStatusTask?.cancel()
      realtimeStatusTask = nil
      realtimeListenerTasks.forEach { $0.cancel() }
      realtimeListenerTasks.removeAll()
      debouncedRemoteRefreshTask?.cancel()
      debouncedRemoteRefreshTask = nil
      if cancelRetry {
         realtimeRetryTask?.cancel()
         realtimeRetryTask = nil
         realtimeRetryAttempt = 0
      }

      if let realtimeChannel {
         Task {
            await supabase.removeChannel(realtimeChannel)
         }
      }
      realtimeChannel = nil
      realtimeUserID = nil
   }

   private func handleRealtimeStreamEnded(for userID: UUID) {
      guard activeUserID == userID, realtimeUserID == userID else { return }
      scheduleRealtimeRetry(for: userID)
   }

   private func scheduleRealtimeRetry(for userID: UUID) {
      guard activeUserID == userID else { return }
      guard realtimeRetryTask == nil || realtimeRetryTask?.isCancelled == true else { return }
      guard realtimeRetryAttempt < 3 else {
         Self.logRealtime("Supabase realtime retry paused after repeated failures.")
         return
      }

      let retryDelays: [UInt64] = [
         2_000_000_000,
         10_000_000_000,
         30_000_000_000
      ]
      realtimeRetryAttempt += 1
      let attempt = realtimeRetryAttempt
      let delayNanoseconds = retryDelays[min(attempt - 1, retryDelays.count - 1)]

      realtimeRetryTask = Task { [weak self] in
         try? await Task.sleep(nanoseconds: delayNanoseconds)
         guard !Task.isCancelled else { return }
         await self?.requestRealtimeSubscription(for: userID, retryAttempt: attempt)
      }
   }

   private func scheduleRemoteRefresh(
      for userID: UUID,
      delayNanoseconds: UInt64 = 150_000_000,
      showsRemoteChangeFeedback: Bool = false
   ) {
      guard activeUserID == userID else { return }

      debouncedRemoteRefreshTask?.cancel()
      debouncedRemoteRefreshTask = Task { [weak self] in
         guard let self else { return }
         try? await Task.sleep(nanoseconds: delayNanoseconds)
         guard !Task.isCancelled else { return }
         await self.refreshFromRemote(for: userID, showsRemoteChangeFeedback: showsRemoteChangeFeedback)
      }
   }

   private static func logRealtime(_ message: String) {
#if DEBUG
      if logsRealtimeDiagnostics {
         AppLog.info(message, logger: AppLog.sync)
      }
#endif
   }

   private static func logSync(_ message: String) {
      AppLog.info(message, logger: AppLog.sync)
   }

   private func requireActiveAccount(for userID: UUID) throws {
      guard SupabaseSyncAccountGuardDisposition.resolve(
         activeUserID: activeUserID,
         requestedUserID: userID,
         taskIsCancelled: Task.isCancelled
      ) == .proceed else {
         throw CancellationError()
      }
   }

   static func isMissingCollaborationSchema(_ error: Error) -> Bool {
      let message = String(describing: error).lowercased()
      return message.contains("schema cache")
         && (message.contains("public.collabs") || message.contains("'collabs'"))
   }

   private func bootstrapLocalCache(for userID: UUID) async -> Bool {
      guard let modelContainer else {
         Self.logSync("Supabase bootstrap local cache skipped: model container is missing.")
         return false
      }

      let shouldAdoptUnownedLocalData = MigrationService.shared.hasPendingLocalDataAdoption(for: userID)
      var didCompleteBootstrap = false
      defer {
         if didCompleteBootstrap, shouldAdoptUnownedLocalData {
            MigrationService.shared.clearPendingLocalDataAdoption(for: userID)
         }
      }

      do {
         Self.logSync("Supabase bootstrap local cache loading: userID=\(userID).")
         SyncCoordinator.shared.updateSyncPhase(.preparingLocalData)
         let context = modelContainer.mainContext
         let didRepairTags = repairDuplicateTags(in: context, ownerUserID: userID)
         let didRepairToDos = repairDuplicateToDos(in: context, ownerUserID: userID)
         if didRepairTags || didRepairToDos {
            try context.save()
         }

         let unownedSnapshot = shouldAdoptUnownedLocalData
            ? try fetchLocalSnapshot(in: context, ownerUserID: nil)
            : .empty
         SyncCoordinator.shared.updateSyncPhase(.uploadingPendingDeletes)
         try await upsertPendingTombstones(for: userID)
         try requireActiveAccount(for: userID)
         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try requireActiveAccount(for: userID)
         try await deleteTombstonedRemoteRecords(remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)
         let didCopyUnownedLocalData = shouldAdoptUnownedLocalData
            ? try copyUnownedSnapshotToUserScopeIfNeeded(
               unownedSnapshot,
               userID: userID,
               remoteSnapshot: remoteSnapshot,
               in: context
            )
            : false
         if didCopyUnownedLocalData {
            try context.save()
         }

         var ownedLocalSnapshot = try fetchLocalSnapshot(
            in: context,
            ownerUserID: userID,
            includesAccessibleCollabs: true
         )
         if applyRemoteTombstones(remoteSnapshot, to: ownedLocalSnapshot, in: context) {
            try context.save()
            ownedLocalSnapshot = try fetchLocalSnapshot(
               in: context,
               ownerUserID: userID,
               includesAccessibleCollabs: true
            )
         }

         if remoteSnapshot.isEmpty, ownedLocalSnapshot.hasContent {
            let didRepairTagCloudIDs = repairTagCloudIDsForUpload(localSnapshot: ownedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            if ensureOwnershipAndCloudIDs(in: ownedLocalSnapshot, userID: userID) || didRepairTagCloudIDs {
               try context.save()
            }
            SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
            let uploadResult = try await upsertLocalSnapshot(ownedLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
            try requireActiveAccount(for: userID)
            markUploadedToDos(uploadResult.uploadedToDoIDs, in: ownedLocalSnapshot)
            try context.save()
            SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
            try await insertMissingToDoTagPairs(localSnapshot: ownedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            try requireActiveAccount(for: userID)

            hasHydratedActiveUser = true
            needsLocalSyncAfterHydration = false
            refreshPlatformSurfaces(from: context)
            SyncCoordinator.shared.completeSyncOperation()
            didCompleteBootstrap = true
            return true
         }

         if didCopyUnownedLocalData {
            var mergedLocalSnapshot = try fetchLocalSnapshot(
               in: context,
               ownerUserID: userID,
               includesAccessibleCollabs: true
            )
            let didRepairMergedTags = repairDuplicateTags(in: context, ownerUserID: userID)
            let didAlignTagIDs = alignTagCloudIDs(localSnapshot: mergedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            let didRepairTagCloudIDs = repairTagCloudIDsForUpload(localSnapshot: mergedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            if didRepairMergedTags || didAlignTagIDs || didRepairTagCloudIDs {
               try context.save()
               mergedLocalSnapshot = try fetchLocalSnapshot(
                  in: context,
                  ownerUserID: userID,
                  includesAccessibleCollabs: true
               )
            }

            SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
            let uploadResult = try await upsertLocalSnapshot(mergedLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
            try requireActiveAccount(for: userID)
            markUploadedToDos(uploadResult.uploadedToDoIDs, in: mergedLocalSnapshot)
            try context.save()
            SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
            try await insertMissingToDoTagPairs(localSnapshot: mergedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            try requireActiveAccount(for: userID)

            SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
            let mergedRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
            try requireActiveAccount(for: userID)
            isApplyingRemoteSnapshot = true
            defer { isApplyingRemoteSnapshot = false }

            SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
            try await apply(remoteSnapshot: mergedRemoteSnapshot, in: context, ownerUserID: userID)
            try requireActiveAccount(for: userID)
            if try repairDuplicatesAfterRemoteApply(in: context, ownerUserID: userID) {
               needsLocalSyncAfterHydration = true
            }
            hasHydratedActiveUser = true
            refreshPlatformSurfaces(from: context)
            SyncCoordinator.shared.completeSyncOperation()
            didCompleteBootstrap = true
            return true
         }

         isApplyingRemoteSnapshot = true
         do {
            defer { isApplyingRemoteSnapshot = false }
            try requireActiveAccount(for: userID)
            SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
            try await apply(remoteSnapshot: remoteSnapshot, in: context, ownerUserID: userID)
            try requireActiveAccount(for: userID)
            if try repairDuplicatesAfterRemoteApply(in: context, ownerUserID: userID) {
               needsLocalSyncAfterHydration = true
            }
         }

         var reconciledLocalSnapshot = try fetchLocalSnapshot(
            in: context,
            ownerUserID: userID,
            includesAccessibleCollabs: true
         )
         let didRepairTagCloudIDs = repairTagCloudIDsForUpload(localSnapshot: reconciledLocalSnapshot, remoteSnapshot: remoteSnapshot)
         if ensureOwnershipAndCloudIDs(in: reconciledLocalSnapshot, userID: userID) || didRepairTagCloudIDs {
            try context.save()
            reconciledLocalSnapshot = try fetchLocalSnapshot(
               in: context,
               ownerUserID: userID,
               includesAccessibleCollabs: true
            )
         }
         SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
         let uploadResult = try await upsertLocalSnapshot(reconciledLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)
         markUploadedToDos(uploadResult.uploadedToDoIDs, in: reconciledLocalSnapshot)
         try context.save()
         SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
         try await reconcileToDoTags(localSnapshot: reconciledLocalSnapshot, remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)

         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let reconciledRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try requireActiveAccount(for: userID)
         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }
         try requireActiveAccount(for: userID)
         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         try await apply(remoteSnapshot: reconciledRemoteSnapshot, in: context, ownerUserID: userID)
         try requireActiveAccount(for: userID)
         if try repairDuplicatesAfterRemoteApply(in: context, ownerUserID: userID) {
            needsLocalSyncAfterHydration = true
         }

         hasHydratedActiveUser = true
         refreshPlatformSurfaces(from: context)
         SyncCoordinator.shared.completeSyncOperation()
         didCompleteBootstrap = true
         return true
      } catch {
         if error is CancellationError { return false }
         AppLog.error("Supabase sync bootstrap failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
         return false
      }
   }

   @discardableResult
   private func pushLocalSnapshot(for userID: UUID) async -> Bool {
      guard activeUserID == userID, let modelContainer else { return false }
      guard !isPushingLocalSnapshot else { return false }

      let measurementStartedAt = AppLog.beginSyncMeasurement("push_local_snapshot")
      var measurementOutcome: StaticString = "success"
      defer {
         AppLog.endSyncMeasurement(
            "push_local_snapshot",
            startedAt: measurementStartedAt,
            outcome: measurementOutcome
         )
      }

      do {
         try requireActiveAccount(for: userID)
         isPushingLocalSnapshot = true
         defer {
            isPushingLocalSnapshot = false
            if needsRemoteRefreshAfterCurrent {
               needsRemoteRefreshAfterCurrent = false
               scheduleRemoteRefresh(for: userID, delayNanoseconds: 350_000_000)
            }
         }

         SyncCoordinator.shared.beginSyncOperation(phase: .preparingLocalData)
         let context = modelContainer.mainContext
         var didRepairTags = repairDuplicateTags(in: context, ownerUserID: userID)
         let didRepairToDos = repairDuplicateToDos(in: context, ownerUserID: userID)
         var localSnapshot = try fetchLocalSnapshot(
            in: context,
            ownerUserID: userID,
            includesAccessibleCollabs: true
         )
         let didAssignCloudIDs = ensureOwnershipAndCloudIDs(in: localSnapshot, userID: userID)
         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try requireActiveAccount(for: userID)
         let didApplyRemoteTombstones = applyRemoteTombstones(remoteSnapshot, to: localSnapshot, in: context)
         let didAlignTagIDs = alignTagCloudIDs(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         let didRepairTagCloudIDs = repairTagCloudIDsForUpload(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         if didRepairTags || didRepairToDos || didAssignCloudIDs || didApplyRemoteTombstones || didAlignTagIDs || didRepairTagCloudIDs {
            try context.save()
            localSnapshot = try fetchLocalSnapshot(
               in: context,
               ownerUserID: userID,
               includesAccessibleCollabs: true
            )
            didRepairTags = false
         }

         SyncCoordinator.shared.updateSyncPhase(.uploadingPendingDeletes)
         try await upsertPendingTombstones(for: userID)
         try requireActiveAccount(for: userID)
         try await deleteTombstonedRemoteRecords(remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)
         SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
         let uploadResult = try await upsertLocalSnapshot(localSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)
         markUploadedToDos(uploadResult.uploadedToDoIDs, in: localSnapshot)
         try context.save()
         SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
         try await reconcileToDoTags(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         try requireActiveAccount(for: userID)

         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let refreshedRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try requireActiveAccount(for: userID)
         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }
         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         try await apply(remoteSnapshot: refreshedRemoteSnapshot, in: context, ownerUserID: userID)
         try requireActiveAccount(for: userID)
         let didRepairRemoteDuplicates = try repairDuplicatesAfterRemoteApply(in: context, ownerUserID: userID)
         isApplyingRemoteSnapshot = false
         if didRepairRemoteDuplicates || needsLocalSyncAfterCurrentApply {
            needsLocalSyncAfterCurrentApply = false
            scheduleLocalSync()
         }
         refreshPlatformSurfaces(from: context)
         SyncCoordinator.shared.completeSyncOperation()
         return true
      } catch {
         if error is CancellationError {
            measurementOutcome = "cancelled"
            return false
         }
         measurementOutcome = "failure"
         AppLog.error("Supabase local push failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
         return false
      }
   }

   private func pullRemoteSnapshot(for userID: UUID, showsRemoteChangeFeedback: Bool = false) async {
      guard activeUserID == userID, let modelContainer else { return }

      let measurementStartedAt = AppLog.beginSyncMeasurement("pull_remote_snapshot")
      var measurementOutcome: StaticString = "success"
      defer {
         AppLog.endSyncMeasurement(
            "pull_remote_snapshot",
            startedAt: measurementStartedAt,
            outcome: measurementOutcome
         )
      }

      do {
         SyncCoordinator.shared.beginSyncOperation(phase: .loadingRemoteChanges)
         let context = modelContainer.mainContext
         let localSnapshot = try fetchLocalSnapshot(
            in: context,
            ownerUserID: userID,
            includesAccessibleCollabs: true
         )
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try requireActiveAccount(for: userID)
         let remoteDeletedToDoCount = remoteDeletedToDoCount(remoteSnapshot: remoteSnapshot, localSnapshot: localSnapshot)
         let didApplyRemoteTombstones = applyRemoteTombstones(remoteSnapshot, to: localSnapshot, in: context)
         let didAlignTagIDs = alignTagCloudIDs(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         if didApplyRemoteTombstones || didAlignTagIDs {
            try context.save()
         }

         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }

         try requireActiveAccount(for: userID)
         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         var applyResult = try await apply(remoteSnapshot: remoteSnapshot, in: context, ownerUserID: userID)
         try requireActiveAccount(for: userID)
         let didRepairRemoteDuplicates = try repairDuplicatesAfterRemoteApply(in: context, ownerUserID: userID)
         applyResult.deletedToDoCount = remoteDeletedToDoCount
         if showsRemoteChangeFeedback, applyResult.changedToDoCount > 0 {
            SyncCoordinator.shared.showTransientFeedback(
               title: String(localized: "toDō updated"),
               message: remoteChangeFeedbackMessage(for: applyResult),
               style: .success
            )
         }
         isApplyingRemoteSnapshot = false
         if didRepairRemoteDuplicates || needsLocalSyncAfterCurrentApply {
            needsLocalSyncAfterCurrentApply = false
            scheduleLocalSync()
         }
         refreshPlatformSurfaces(from: context)
         SyncCoordinator.shared.completeSyncOperation()
      } catch {
         if error is CancellationError {
            measurementOutcome = "cancelled"
            return
         }
         measurementOutcome = "failure"
         AppLog.error("Supabase remote refresh failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
      }
   }

   private func fetchRemoteSnapshot(for userID: UUID) async throws -> SupabaseRemoteSnapshot {
      let remoteSnapshot = try await fetchRawRemoteSnapshot(for: userID)
      try requireActiveAccount(for: userID)
      let didCleanUpDuplicates = try await cleanupDuplicateRemoteToDos(in: remoteSnapshot, actingUserID: userID)
      try requireActiveAccount(for: userID)
      guard didCleanUpDuplicates else {
         return remoteSnapshot
      }
      SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
      let refreshedSnapshot = try await fetchRawRemoteSnapshot(for: userID)
      try requireActiveAccount(for: userID)
      return refreshedSnapshot
   }

   private func fetchRawRemoteSnapshot(for userID: UUID) async throws -> SupabaseRemoteSnapshot {
      let collabs: [SupabaseCollabIDRecord]
      do {
         collabs = try await supabase
            .from("collabs")
            .select("id")
            .execute()
            .value
      } catch where Self.isMissingCollaborationSchema(error) {
         // Collaboration ships behind a database migration. Personal sync must
         // remain available while a deployment is rolling between versions.
         collabs = []
      }
      guard activeUserID == userID else { throw CancellationError() }
      accessibleCollabIDs = Set(collabs.map(\.id))

      async let tags: [SupabaseTagRecord] = supabase
         .from("tags")
         .select()
         .execute()
         .value

      async let toDos: [SupabaseToDoRecord] = supabase
         .from("todos")
         .select()
         .execute()
         .value

      async let nanoDos: [SupabaseNanoDoRecord] = supabase
         .from("nanodos")
         .select()
         .execute()
         .value

      async let toDoTags: [SupabaseToDoTagRecord] = supabase
         .from("todo_tags")
         .select()
         .execute()
         .value

      async let tombstones: [SupabaseTombstoneRecord] = supabase
         .from("sync_tombstones")
         .select()
         .execute()
         .value

      let resolvedToDos = try await toDos
      let resolvedTags = try await tags
      let resolvedNanoDos = try await nanoDos
      let resolvedToDoTags = try await toDoTags
      let resolvedTombstones = try await tombstones
      try requireActiveAccount(for: userID)

      Self.logSync(
         "Supabase remote snapshot loaded: tags=\(resolvedTags.count), todos=\(resolvedToDos.count), nanodos=\(resolvedNanoDos.count), todo_tags=\(resolvedToDoTags.count), tombstones=\(resolvedTombstones.count), todoStates=\(remoteToDoStateSummary(resolvedToDos))"
      )

      return SupabaseRemoteSnapshot(
         tags: resolvedTags,
         toDos: resolvedToDos,
         nanoDos: resolvedNanoDos,
         toDoTags: resolvedToDoTags,
         tombstones: resolvedTombstones
      )
   }

   @discardableResult
   private func cleanupDuplicateRemoteToDos(
      in remoteSnapshot: SupabaseRemoteSnapshot,
      actingUserID: UUID
   ) async throws -> Bool {
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let activeToDos = remoteSnapshot.toDos.filter {
         $0.userID == actingUserID && !tombstonedToDoIDs.contains($0.id)
      }
      guard activeToDos.count > 1 else { return false }

      let groupedToDos = Dictionary(grouping: activeToDos, by: remoteSemanticDuplicateKey(for:))
      let remoteChildCountsByToDoID = remoteToDoChildCounts(in: remoteSnapshot)
      var tombstones: [SupabaseTombstoneUpsertPayload] = []

      for duplicates in groupedToDos.values where duplicates.count > 1 {
         // Distinct cloud IDs can only be collapsed when every record carries
         // the same persisted creation identity. Legacy rows without one are
         // ambiguous and must remain separate.
         guard duplicates.allSatisfy({ $0.createdAt != nil }) else { continue }
         guard let canonical = duplicates.sorted(by: {
            shouldPreferRemoteToDoAsCanonical($0, over: $1, childCountsByToDoID: remoteChildCountsByToDoID)
         }).first else { continue }

         for duplicate in duplicates where duplicate.id != canonical.id {
            tombstones.append(
               SupabaseTombstoneUpsertPayload(
                  userID: actingUserID,
                  collabID: duplicate.collabID,
                  recordTable: .toDos,
                  recordID: duplicate.id
               )
            )
         }
      }

      guard !tombstones.isEmpty else { return false }
      SyncCoordinator.shared.updateSyncPhase(.cleaningRemoteDuplicates)
      try await upsertTombstones(tombstones)

      for tombstone in tombstones {
         try await deleteRemoteRecord(table: .toDos, id: tombstone.recordID)
      }

      return true
   }

   private func fetchLocalSnapshot(
      in context: ModelContext,
      ownerUserID: UUID?,
      includesAccessibleCollabs: Bool = false
   ) throws -> LocalSnapshot {
      let allToDos = try context.fetch(FetchDescriptor<ToDo>())
      let toDos = allToDos.filter { toDo in
         toDo.ownerUserID == ownerUserID
         || (includesAccessibleCollabs && toDo.collabID.map(accessibleCollabIDs.contains) == true)
      }
      let visibleToDoIDs = Set(toDos.map(\.id))
      let allNanoDos = try context.fetch(FetchDescriptor<NanoDo>())
      let nanoDos = allNanoDos.filter { nanoDo in
         nanoDo.ownerUserID == ownerUserID
         || (includesAccessibleCollabs && nanoDo.toDo.map { visibleToDoIDs.contains($0.id) } == true)
      }
      let visibleTagIDs = Set(toDos.flatMap(\.effectiveTags).map(\.id))
      let tags = try context.fetch(FetchDescriptor<Tag>()).filter { tag in
         tag.ownerUserID == ownerUserID
         || (includesAccessibleCollabs && visibleTagIDs.contains(tag.id))
      }
      let conflicts = try context.fetch(FetchDescriptor<SyncConflict>()).filter {
         !$0.isResolved && $0.userID == ownerUserID
      }
      return LocalSnapshot(tags: tags, toDos: toDos, nanoDos: nanoDos, conflicts: conflicts)
   }

   private func fetchTags(in context: ModelContext, ownerUserID: UUID?) throws -> [Tag] {
      try context.fetch(FetchDescriptor<Tag>()).filter { $0.ownerUserID == ownerUserID }
   }

   private func fetchToDos(in context: ModelContext, ownerUserID: UUID?) throws -> [ToDo] {
      try context.fetch(FetchDescriptor<ToDo>()).filter { $0.ownerUserID == ownerUserID }
   }

   private func fetchNanoDos(in context: ModelContext, ownerUserID: UUID?) throws -> [NanoDo] {
      try context.fetch(FetchDescriptor<NanoDo>()).filter { $0.ownerUserID == ownerUserID }
   }

   private func fetchUnresolvedConflicts(in context: ModelContext, userID: UUID?) throws -> [SyncConflict] {
      try context.fetch(FetchDescriptor<SyncConflict>()).filter {
         !$0.isResolved && $0.userID == userID
      }
      .sorted { $0.createdAt > $1.createdAt }
   }

   @discardableResult
   private func copyUnownedSnapshotToUserScopeIfNeeded(
      _ snapshot: LocalSnapshot,
      userID: UUID,
      remoteSnapshot: SupabaseRemoteSnapshot,
      in context: ModelContext
   ) throws -> Bool {
      guard snapshot.hasContent else { return false }

      let ownedSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
      let remoteToDoIDsByDuplicateKey = Dictionary(grouping: remoteSnapshot.toDos, by: remoteSemanticDuplicateKey(for:))
         .compactMapValues { records in
            records.sorted { lhs, rhs in
               remoteTimestamp(createdAt: lhs.createdAt, updatedAt: lhs.updatedAt) > remoteTimestamp(createdAt: rhs.createdAt, updatedAt: rhs.updatedAt)
            }.first?.id
         }
      var ownedTagsByName: [String: Tag] = [:]
      for tag in ownedSnapshot.tags where ownedTagsByName[Tag.normalizeName(tag.name)] == nil {
         ownedTagsByName[Tag.normalizeName(tag.name)] = tag
      }
      var clonedTagsBySourceID: [PersistentIdentifier: Tag] = [:]
      var didChange = false

      for sourceTag in snapshot.tags {
         let sourceTagName = Tag.normalizeName(sourceTag.name)
         if let existingTag = ownedTagsByName[sourceTagName] {
            clonedTagsBySourceID[sourceTag.id] = existingTag
            continue
         }

         let clonedTag = Tag(
            name: sourceTag.name,
            createdAt: sourceTag.createdAt,
            updatedAt: sourceTag.updatedAt,
            cloudID: UUID(),
            ownerUserID: userID
         )
         context.insert(clonedTag)
         ownedTagsByName[sourceTagName] = clonedTag
         clonedTagsBySourceID[sourceTag.id] = clonedTag
         didChange = true
      }

      var ownedToDosByCloudID: [UUID: ToDo] = [:]
      for toDo in ownedSnapshot.toDos {
         if let cloudID = toDo.cloudID, ownedToDosByCloudID[cloudID] == nil {
            ownedToDosByCloudID[cloudID] = toDo
         }
      }
      var ownedToDosByDuplicateKey: [ToDoSemanticDuplicateKey: ToDo] = [:]
      for toDo in ownedSnapshot.toDos where ownedToDosByDuplicateKey[semanticDuplicateKey(for: toDo)] == nil {
         ownedToDosByDuplicateKey[semanticDuplicateKey(for: toDo)] = toDo
      }
      var clonedToDosBySourceID: [PersistentIdentifier: ToDo] = [:]

      for sourceToDo in snapshot.toDos {
         let sourceDuplicateKey = semanticDuplicateKey(for: sourceToDo)
         let sourceCloudID = sourceToDo.cloudID
         ?? remoteToDoIDsByDuplicateKey[sourceDuplicateKey]
         ?? UUID()
         if sourceToDo.cloudID == nil {
            sourceToDo.cloudID = sourceCloudID
            didChange = true
         }

         if let existingToDo = ownedToDosByCloudID[sourceCloudID] ?? ownedToDosByDuplicateKey[sourceDuplicateKey] {
            if existingToDo.cloudID == nil {
               existingToDo.cloudID = sourceCloudID
               didChange = true
            }
            clonedToDosBySourceID[sourceToDo.id] = existingToDo
            continue
         }

         let clonedToDo = ToDo(
            task: sourceToDo.task,
            notes: sourceToDo.notes,
            createdAt: sourceToDo.createdAt,
            updatedAt: sourceToDo.updatedAt,
            completedAt: sourceToDo.completedAt,
            dueDate: sourceToDo.dueDate,
            reminderIntent: sourceToDo.reminderIntent,
            recurrenceUnit: sourceToDo.recurrenceUnit,
            recurrenceInterval: sourceToDo.recurrenceInterval,
            recurrenceMode: sourceToDo.recurrenceMode,
            recurrenceCount: sourceToDo.recurrenceCount,
            recurrenceAnchorDate: sourceToDo.recurrenceAnchorDate,
            recurrenceEndDate: sourceToDo.recurrenceEndDate,
            lifecycleState: sourceToDo.lifecycleState,
            isDone: sourceToDo.isDone,
            completeWhenAllNanoDosDone: sourceToDo.completeWhenAllNanoDosDone,
            nanoDos: [],
            tag: nil,
            tags: [],
            cloudID: sourceCloudID,
            ownerUserID: userID
         )
         context.insert(clonedToDo)
         clonedToDo.setSelectedTags(sourceToDo.effectiveTags.compactMap { clonedTagsBySourceID[$0.id] })
         clonedToDo.updatedAt = sourceToDo.updatedAt
         clonedToDo.completedAt = sourceToDo.completedAt
         ownedToDosByCloudID[sourceCloudID] = clonedToDo
         ownedToDosByDuplicateKey[sourceDuplicateKey] = clonedToDo
         clonedToDosBySourceID[sourceToDo.id] = clonedToDo
         didChange = true
      }

      let ownedNanoDoCloudIDs = Set(ownedSnapshot.nanoDos.compactMap(\.cloudID))
      var clonedNanoDosByToDoID: [PersistentIdentifier: [NanoDo]] = [:]

      for sourceNanoDo in snapshot.nanoDos {
         let clonedParent = sourceNanoDo.toDo.flatMap { clonedToDosBySourceID[$0.id] }
         let sourceCloudID = sourceNanoDo.cloudID ?? UUID()
         if sourceNanoDo.cloudID == nil {
            sourceNanoDo.cloudID = sourceCloudID
            didChange = true
         }
         guard !ownedNanoDoCloudIDs.contains(sourceCloudID) else { continue }

         let clonedTag = sourceNanoDo.tag.flatMap { clonedTagsBySourceID[$0.id] }
         let clonedNanoDo = NanoDo(
            task: sourceNanoDo.task,
            createdAt: sourceNanoDo.createdAt,
            updatedAt: sourceNanoDo.updatedAt,
            dueDate: sourceNanoDo.dueDate,
            isDone: sourceNanoDo.isDone,
            toDo: clonedParent,
            tag: clonedTag ?? clonedParent?.effectiveTags.first,
            cloudID: sourceCloudID,
            ownerUserID: userID
         )
         context.insert(clonedNanoDo)

         if let sourceParentID = sourceNanoDo.toDo?.id {
            clonedNanoDosByToDoID[sourceParentID, default: []].append(clonedNanoDo)
         }
         didChange = true
      }

      for (sourceToDoID, clonedToDo) in clonedToDosBySourceID {
         clonedToDo.nanoDos = clonedNanoDosByToDoID[sourceToDoID, default: clonedToDo.nanoDos]
      }

      if didChange {
         AppLog.info("Copied local toDōs into toDō Sync scope for user \(userID).", logger: AppLog.sync)
      }
      return didChange
   }

   @discardableResult
   private func ensureOwnershipAndCloudIDs(in snapshot: LocalSnapshot, userID: UUID) -> Bool {
      var didChange = false
      for tag in snapshot.tags {
         if tag.ownerUserID == nil {
            tag.ownerUserID = userID
            didChange = true
         } else if tag.ownerUserID != userID {
            continue
         } else if tag.cloudID == nil {
            tag.cloudID = UUID()
            didChange = true
         }
      }

      for toDo in snapshot.toDos {
         if toDo.ownerUserID == nil {
            toDo.ownerUserID = userID
            didChange = true
         } else if toDo.ownerUserID != userID {
            continue
         } else if toDo.cloudID == nil {
            toDo.cloudID = UUID()
            didChange = true
         }
      }

      for nanoDo in snapshot.nanoDos {
         if nanoDo.ownerUserID == nil {
            nanoDo.ownerUserID = userID
            didChange = true
         } else if nanoDo.ownerUserID != userID {
            continue
         } else if nanoDo.cloudID == nil {
            nanoDo.cloudID = UUID()
            didChange = true
         }
      }

      return didChange
   }

   @discardableResult
   private func repairDuplicateTags(in context: ModelContext, ownerUserID: UUID?) -> Bool {
      let tags = (try? fetchTags(in: context, ownerUserID: ownerUserID)) ?? []
      guard tags.count > 1 else { return false }

      let grouped = Dictionary(grouping: tags) { tag in
         Tag.normalizeName(tag.name)
      }
      var didChange = false

      for duplicates in grouped.values where duplicates.count > 1 {
         guard let canonical = duplicates.sorted(by: Tag.shouldPreferCanonical(_:over:)).first else { continue }

         for duplicate in duplicates where duplicate.id != canonical.id {
            if canonical.cloudID == nil, let duplicateCloudID = duplicate.cloudID {
               canonical.cloudID = duplicateCloudID
            }

            for toDo in duplicate.allToDos {
               var mergedTags = toDo.effectiveTags.filter { $0.id != duplicate.id }
               if !mergedTags.contains(where: { $0.id == canonical.id }) {
                  mergedTags.append(canonical)
               }
               toDo.setSelectedTags(mergedTags)
               if toDo.tag?.id == duplicate.id {
                  toDo.tag = canonical
               }
            }

            for nanoDo in duplicate.allNanoDos where nanoDo.tag?.id == duplicate.id {
               nanoDo.tag = canonical
            }

            context.delete(duplicate)
            didChange = true
         }
      }

      return didChange
   }

   @discardableResult
   private func repairDuplicateToDos(in context: ModelContext, ownerUserID: UUID?) -> Bool {
      var didChange = false

      var toDos = (try? fetchToDos(in: context, ownerUserID: ownerUserID)) ?? []
      guard toDos.count > 1 else { return false }

      // A cloud ID is the authoritative identity. Repair these duplicates first
      // even when their mutable fields differ, which can happen after two local
      // objects race during hydration and editing.
      var toDosByCloudID: [UUID: [ToDo]] = [:]
      for toDo in toDos {
         guard let cloudID = toDo.cloudID else { continue }
         toDosByCloudID[cloudID, default: []].append(toDo)
      }

      for duplicates in toDosByCloudID.values where duplicates.count > 1 {
         guard let canonical = duplicates.sorted(by: shouldPreferAsCanonical(_:over:)).first else { continue }
         for duplicate in duplicates where duplicate.id != canonical.id {
            mergeRelationships(from: duplicate, into: canonical)
            context.delete(duplicate)
            didChange = true
         }
      }

      if didChange {
         toDos = (try? fetchToDos(in: context, ownerUserID: ownerUserID)) ?? []
      }

      let grouped = Dictionary(grouping: toDos, by: semanticDuplicateKey(for:))

      for duplicates in grouped.values where duplicates.count > 1 {
         guard let canonical = duplicates.sorted(by: shouldPreferAsCanonical(_:over:)).first else { continue }

         for duplicate in duplicates where duplicate.id != canonical.id {
            if canonical.cloudID == nil, let duplicateCloudID = duplicate.cloudID {
               canonical.cloudID = duplicateCloudID
               canonical.lastSyncedUpdatedAt = duplicate.lastSyncedUpdatedAt
               didChange = true
            }

            if let duplicateCloudID = duplicate.cloudID,
               duplicateCloudID != canonical.cloudID {
               SyncTombstoneStore.recordDelete(
                  table: .toDos,
                  recordID: duplicateCloudID,
                  userID: ownerUserID,
                  collabID: duplicate.collabID
               )
            }

            mergeRelationships(from: duplicate, into: canonical)

            context.delete(duplicate)
            didChange = true
         }
      }

      return didChange
   }

   private func mergeRelationships(from duplicate: ToDo, into canonical: ToDo) {
      let preservedUpdatedAt = canonical.updatedAt
      let mergedTags = canonical.effectiveTags + duplicate.effectiveTags
      canonical.setSelectedTags(mergedTags)
      canonical.updatedAt = preservedUpdatedAt

      let duplicateNanoDos = duplicate.nanoDos
      for nanoDo in duplicateNanoDos {
         nanoDo.toDo = canonical
      }
      duplicate.nanoDos = []

      if canonical.ownerUserID == nil {
         canonical.ownerUserID = duplicate.ownerUserID
      }
      if canonical.collabID == nil {
         canonical.collabID = duplicate.collabID
      }
   }

   @discardableResult
   private func repairDuplicatesAfterRemoteApply(in context: ModelContext, ownerUserID: UUID) throws -> Bool {
      let didRepairTags = repairDuplicateTags(in: context, ownerUserID: ownerUserID)
      let didRepairToDos = repairDuplicateToDos(in: context, ownerUserID: ownerUserID)
      guard didRepairTags || didRepairToDos else { return false }
      try context.save()
      return true
   }

   private func shouldPreferAsCanonical(_ lhs: ToDo, over rhs: ToDo) -> Bool {
      if lhs.cloudID != nil, rhs.cloudID == nil { return true }
      if lhs.cloudID == nil, rhs.cloudID != nil { return false }
      if lhs.syncUpdatedAt != rhs.syncUpdatedAt { return lhs.syncUpdatedAt > rhs.syncUpdatedAt }
      if lhs.lastSyncedUpdatedAt != nil, rhs.lastSyncedUpdatedAt == nil { return true }
      if lhs.lastSyncedUpdatedAt == nil, rhs.lastSyncedUpdatedAt != nil { return false }
      if lhs.nanoDos.count != rhs.nanoDos.count { return lhs.nanoDos.count > rhs.nanoDos.count }
      return (lhs.cloudID?.uuidString ?? lhs.id.hashValue.description) < (rhs.cloudID?.uuidString ?? rhs.id.hashValue.description)
   }

   private func duplicateKey(for toDo: ToDo) -> ToDoDuplicateKey {
      ToDoDuplicateKey(
         task: toDo.task,
         notes: toDo.notes,
         isDone: toDo.isDone,
         lifecycleState: toDo.lifecycleState.rawValue,
         reminderIntent: toDo.reminderIntent.rawValue,
         createdAt: timestampKey(toDo.createdAt),
         dueAt: timestampKey(toDo.dueDate),
         recurrenceUnit: toDo.recurrenceUnit?.rawValue,
         recurrenceInterval: toDo.recurrenceInterval,
         recurrenceMode: toDo.recurrenceMode?.rawValue,
         recurrenceCount: toDo.recurrenceCount,
         recurrenceAnchorAt: timestampKey(toDo.recurrenceAnchorDate ?? toDo.dueDate),
         recurrenceEndAt: timestampKey(toDo.recurrenceEndDate)
      )
   }

   private func semanticDuplicateKey(for toDo: ToDo) -> ToDoSemanticDuplicateKey {
      ToDoSemanticDuplicateKey(
         collabID: toDo.collabID,
         task: toDo.task,
         notes: toDo.notes,
         isDone: toDo.isDone,
         lifecycleState: toDo.lifecycleState.rawValue,
         reminderIntent: toDo.reminderIntent.rawValue,
         createdAt: timestampKey(toDo.createdAt),
         dueAt: timestampKey(toDo.dueDate),
         recurrenceUnit: toDo.recurrenceUnit?.rawValue,
         recurrenceInterval: toDo.recurrenceInterval,
         recurrenceMode: toDo.recurrenceMode?.rawValue,
         recurrenceCount: toDo.recurrenceCount,
         recurrenceAnchorAt: timestampKey(toDo.recurrenceAnchorDate ?? toDo.dueDate),
         recurrenceEndAt: timestampKey(toDo.recurrenceEndDate)
      )
   }

   private func remoteDuplicateKey(for record: SupabaseToDoRecord) -> ToDoDuplicateKey {
      ToDoDuplicateKey(
         task: record.task,
         notes: record.notes,
         isDone: record.isDone,
         lifecycleState: record.lifecycleState,
         reminderIntent: record.reminderIntent,
         createdAt: timestampKey(record.createdAt),
         dueAt: timestampKey(record.dueAt),
         recurrenceUnit: record.recurrenceUnit,
         recurrenceInterval: record.recurrenceInterval,
         recurrenceMode: record.recurrenceMode,
         recurrenceCount: record.recurrenceCount,
         recurrenceAnchorAt: timestampKey(record.recurrenceAnchorAt ?? record.dueAt),
         recurrenceEndAt: timestampKey(record.recurrenceEndAt)
      )
   }

   private func remoteSemanticDuplicateKey(for record: SupabaseToDoRecord) -> ToDoSemanticDuplicateKey {
      ToDoSemanticDuplicateKey(
         collabID: record.collabID,
         task: record.task,
         notes: record.notes,
         isDone: record.isDone,
         lifecycleState: record.lifecycleState,
         reminderIntent: record.reminderIntent,
         createdAt: timestampKey(record.createdAt),
         dueAt: timestampKey(record.dueAt),
         recurrenceUnit: record.recurrenceUnit,
         recurrenceInterval: record.recurrenceInterval,
         recurrenceMode: record.recurrenceMode,
         recurrenceCount: record.recurrenceCount,
         recurrenceAnchorAt: timestampKey(record.recurrenceAnchorAt ?? record.dueAt),
         recurrenceEndAt: timestampKey(record.recurrenceEndAt)
      )
   }

   private func shouldPreferRemoteToDoAsCanonical(
      _ lhs: SupabaseToDoRecord,
      over rhs: SupabaseToDoRecord,
      childCountsByToDoID: [UUID: Int]
   ) -> Bool {
      let lhsChildCount = childCountsByToDoID[lhs.id, default: 0]
      let rhsChildCount = childCountsByToDoID[rhs.id, default: 0]
      if lhsChildCount != rhsChildCount {
         return lhsChildCount > rhsChildCount
      }

      let lhsTimestamp = remoteTimestamp(createdAt: lhs.createdAt, updatedAt: lhs.updatedAt)
      let rhsTimestamp = remoteTimestamp(createdAt: rhs.createdAt, updatedAt: rhs.updatedAt)
      if lhsTimestamp != rhsTimestamp {
         return lhsTimestamp > rhsTimestamp
      }

      return lhs.id.uuidString < rhs.id.uuidString
   }

   private func remoteToDoChildCounts(in remoteSnapshot: SupabaseRemoteSnapshot) -> [UUID: Int] {
      var counts: [UUID: Int] = [:]
      for nanoDo in remoteSnapshot.nanoDos {
         counts[nanoDo.todoID, default: 0] += 1
      }
      for toDoTag in remoteSnapshot.toDoTags {
         counts[toDoTag.todoID, default: 0] += 1
      }
      return counts
   }

   private func timestampKey(_ date: Date?) -> Int64? {
      guard let date else { return nil }
      return Int64((date.timeIntervalSince1970 * 1_000).rounded())
   }

   @discardableResult
   private func alignTagCloudIDs(localSnapshot: LocalSnapshot, remoteSnapshot: SupabaseRemoteSnapshot) -> Bool {
      let remoteByName = Dictionary(grouping: remoteSnapshot.tags, by: {
         TagIdentityKey(ownerUserID: $0.userID, normalizedName: Tag.normalizeName($0.name))
      })
         .compactMapValues { records in
            records.sorted { lhs, rhs in
               switch (lhs.updatedAt, rhs.updatedAt) {
               case let (lhsUpdated?, rhsUpdated?):
                  return lhsUpdated > rhsUpdated
               case (_?, nil):
                  return true
               case (nil, _?):
                  return false
               case (nil, nil):
                  return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
               }
            }
            .first
         }
      var didChange = false

      for tag in localSnapshot.tags {
         guard let ownerUserID = tag.ownerUserID,
               let remoteRecord = remoteByName[
                  TagIdentityKey(ownerUserID: ownerUserID, normalizedName: Tag.normalizeName(tag.name))
               ]
         else { continue }
         if tag.cloudID != remoteRecord.id {
            tag.cloudID = remoteRecord.id
            didChange = true
         }
         if tag.ownerUserID != remoteRecord.userID {
            tag.ownerUserID = remoteRecord.userID
            didChange = true
         }
      }

      return didChange
   }

   @discardableResult
   private func repairTagCloudIDsForUpload(localSnapshot: LocalSnapshot, remoteSnapshot: SupabaseRemoteSnapshot) -> Bool {
      guard let activeUserID else { return false }

      let remoteTagsByID = Dictionary(remoteSnapshot.tags.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      let remoteTagsByName = Dictionary(grouping: remoteSnapshot.tags, by: {
         TagIdentityKey(ownerUserID: $0.userID, normalizedName: Tag.normalizeName($0.name))
      })
         .compactMapValues { records in
            records.sorted { lhs, rhs in
               switch (lhs.updatedAt, rhs.updatedAt) {
               case let (lhsUpdated?, rhsUpdated?):
                  return lhsUpdated > rhsUpdated
               case (_?, nil):
                  return true
               case (nil, _?):
                  return false
               case (nil, nil):
                  return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
               }
            }
            .first
         }
      var didChange = false

      for tag in localSnapshot.tags {
         let remoteTagForID = tag.cloudID.flatMap { remoteTagsByID[$0] }
         let matchingOwnedTag = tag.ownerUserID.flatMap { ownerUserID in
            remoteTagsByName[
               TagIdentityKey(ownerUserID: ownerUserID, normalizedName: Tag.normalizeName(tag.name))
            ]
         }

         switch SupabaseTagCloudIDRepairDisposition.resolve(
            localOwnerID: tag.ownerUserID,
            activeUserID: activeUserID,
            localCloudID: tag.cloudID,
            remoteRecordID: remoteTagForID?.id,
            remoteRecordOwnerID: remoteTagForID?.userID,
            matchingOwnedRecordID: matchingOwnedTag?.id
         ) {
         case .retain:
            continue
         case .relink(let cloudID):
            if tag.cloudID != cloudID {
               tag.cloudID = cloudID
               didChange = true
            }
         case .assignNew:
            tag.cloudID = UUID()
            didChange = true
         }
      }

      if didChange {
         Self.logSync("Supabase repaired local tag cloud IDs before upload.")
      }
      return didChange
   }

   @discardableResult
   private func apply(remoteSnapshot: SupabaseRemoteSnapshot, in context: ModelContext, ownerUserID: UUID) async throws -> RemoteApplyResult {
      let localSnapshot = try fetchLocalSnapshot(
         in: context,
         ownerUserID: ownerUserID,
         includesAccessibleCollabs: true
      )
      let localTagsByCloudID = firstLocalRecordByCloudID(localSnapshot.tags)
      let localToDosByCloudID = firstLocalRecordByCloudID(localSnapshot.toDos)
      let localNanoDosByCloudID = firstLocalRecordByCloudID(localSnapshot.nanoDos)
      let tombstonedTagIDs = remoteSnapshot.tombstonedIDs(for: .tags)
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let tombstonedNanoDoIDs = remoteSnapshot.tombstonedIDs(for: .nanoDos)
      let activeTagRecords = remoteSnapshot.tags.filter { !tombstonedTagIDs.contains($0.id) }
      let activeToDoRecords = remoteSnapshot.toDos.filter { !tombstonedToDoIDs.contains($0.id) }
      let activeNanoDoRecords = remoteSnapshot.nanoDos.filter {
         !tombstonedNanoDoIDs.contains($0.id)
         && !tombstonedToDoIDs.contains($0.todoID)
      }
      let activeToDoTagRecords = remoteSnapshot.toDoTags.filter {
         !tombstonedToDoIDs.contains($0.todoID)
         && !tombstonedTagIDs.contains($0.tagID)
      }
      Self.logSync(
         "Supabase applying snapshot: nonTombstonedTags=\(activeTagRecords.count), nonTombstonedToDos=\(activeToDoRecords.count), nonTombstonedNanoDos=\(activeNanoDoRecords.count), nonTombstonedToDoTags=\(activeToDoTagRecords.count), todoStates=\(remoteToDoStateSummary(activeToDoRecords))"
      )

      let canonicalActiveTagRecords = canonicalRemoteTags(activeTagRecords)
      var syncedTagsByCloudID: [UUID: Tag] = [:]
      for record in canonicalActiveTagRecords {
         let existingTag = localTagsByCloudID[record.id]
         let existingTagByName = localSnapshot.tags
            .filter {
               $0.ownerUserID == record.userID
               && Tag.normalizeName($0.name) == Tag.normalizeName(record.name)
            }
            .sorted(by: Tag.shouldPreferCanonical(_:over:))
            .first
         let tag = existingTag ?? existingTagByName ?? Tag(
            name: record.name,
            createdAt: record.createdAt ?? .now,
            updatedAt: record.updatedAt ?? record.createdAt,
            cloudID: record.id,
            ownerUserID: record.userID
         )
         if tag.modelContext == nil {
            context.insert(tag)
         }
         guard existingTag == nil || shouldApplyRemote(
            localUpdatedAt: tag.syncUpdatedAt,
            remoteCreatedAt: record.createdAt,
            remoteUpdatedAt: record.updatedAt
         ) else {
            syncedTagsByCloudID[record.id] = tag
            continue
         }
         tag.cloudID = record.id
         tag.ownerUserID = record.userID
         tag.name = Tag.normalizeName(record.name)
         if let createdAt = record.createdAt {
            tag.createdAt = createdAt
         }
         tag.updatedAt = remoteTimestamp(createdAt: record.createdAt, updatedAt: record.updatedAt)
         syncedTagsByCloudID[record.id] = tag
      }
      mapDuplicateRemoteTagIDs(activeTagRecords, canonicalRecords: canonicalActiveTagRecords, into: &syncedTagsByCloudID)

      await Task.yield()

      var syncedToDosByCloudID: [UUID: ToDo] = [:]
      var remoteAppliedToDoIDs = Set<UUID>()
      for record in activeToDoRecords {
         let existingToDo = localToDosByCloudID[record.id]
         let toDo = existingToDo ?? ToDo(
            task: record.task,
            notes: record.notes,
            createdAt: record.createdAt ?? .now,
            updatedAt: record.updatedAt ?? record.createdAt,
            completedAt: record.completedAt,
            dueDate: record.dueAt,
            reminderIntent: ToDoReminderIntent(rawValue: record.reminderIntent) ?? .soft,
            lifecycleState: ToDoState(rawValue: record.lifecycleState) ?? .active,
            completeWhenAllNanoDosDone: record.completeWhenAllNanoDosDone ?? false,
            cloudID: record.id,
            ownerUserID: record.userID,
            collabID: record.collabID
         )
         if toDo.modelContext == nil {
            context.insert(toDo)
         }
         let remoteUpdatedAt = remoteTimestamp(createdAt: record.createdAt, updatedAt: record.updatedAt)
         if existingToDo != nil,
            hasTwoSidedToDoConflict(localToDo: toDo, remoteTimestamp: remoteUpdatedAt) {
            let didRecordConflict = SyncConflictStore.recordToDoConflict(
               localToDo: toDo,
               syncedRecord: SupabaseSyncedToDoConflictRecord(
                  task: record.task,
                  notes: record.notes,
                  isDone: record.isDone,
                  updatedAt: remoteUpdatedAt,
                  lifecycleState: ToDoState(rawValue: record.lifecycleState) ?? .active,
                  reminderIntent: ToDoReminderIntent(rawValue: record.reminderIntent) ?? (record.dueAt == nil ? .soft : .due),
                  dueDate: record.dueAt,
                  recurrenceUnit: record.recurrenceUnit.flatMap(ToDoRecurrenceUnit.init(rawValue:)),
                  recurrenceInterval: record.recurrenceInterval,
                  recurrenceMode: record.recurrenceMode.flatMap(ToDoRecurrenceMode.init(rawValue:)),
                  recurrenceCount: record.recurrenceCount,
                  recurrenceAnchorDate: record.recurrenceAnchorAt ?? record.dueAt,
                  recurrenceEndDate: record.recurrenceEndAt
               ),
               userID: ownerUserID,
               in: context
            )
            if didRecordConflict {
               SyncCoordinator.shared.showTransientFeedback(
                  title: String(localized: "Choose a Version"),
                  message: String(localized: "A toDō changed on more than one device. Review it in Settings."),
                  style: .warning
               )
            }
            syncedToDosByCloudID[record.id] = toDo
            continue
         }
         guard existingToDo == nil || shouldApplyRemote(
            localUpdatedAt: toDo.syncUpdatedAt,
            remoteCreatedAt: record.createdAt,
            remoteUpdatedAt: record.updatedAt
         ) else {
            syncedToDosByCloudID[record.id] = toDo
            continue
         }
         toDo.cloudID = record.id
         toDo.ownerUserID = record.userID
         toDo.collabID = record.collabID
         toDo.task = record.task
         toDo.notes = record.notes
         if let createdAt = record.createdAt {
            toDo.createdAt = createdAt
         }
         toDo.dueDate = record.dueAt
         toDo.reminderIntent = ToDoReminderIntent(rawValue: record.reminderIntent) ?? (record.dueAt == nil ? .soft : .due)
         if record.isRecurring == true {
            toDo.recurrenceUnit = record.recurrenceUnit.flatMap(ToDoRecurrenceUnit.init(rawValue:))
            toDo.recurrenceInterval = record.recurrenceInterval
            toDo.recurrenceMode = record.recurrenceMode.flatMap(ToDoRecurrenceMode.init(rawValue:))
            toDo.recurrenceCount = record.recurrenceCount
            toDo.recurrenceAnchorDate = record.recurrenceAnchorAt ?? record.dueAt
            toDo.recurrenceEndDate = record.recurrenceEndAt
         } else {
            toDo.clearRecurrence()
         }
         toDo.transition(to: ToDoState(rawValue: record.lifecycleState) ?? .active)
         toDo.completedAt = record.completedAt ?? (record.lifecycleState == ToDoState.done.rawValue ? remoteUpdatedAt : nil)
         toDo.trashedAt = record.lifecycleState == ToDoState.trashed.rawValue
            ? (record.trashedAt ?? remoteUpdatedAt)
            : nil
         toDo.completeWhenAllNanoDosDone = record.completeWhenAllNanoDosDone ?? false
         toDo.updatedAt = remoteUpdatedAt
         toDo.lastSyncedUpdatedAt = remoteUpdatedAt
         remoteAppliedToDoIDs.insert(record.id)
         syncedToDosByCloudID[record.id] = toDo
      }

      await Task.yield()

      let groupedTagIDsByToDoID = Dictionary(grouping: activeToDoTagRecords, by: \.todoID)
      let activeToDoRecordsByID = Dictionary(activeToDoRecords.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      var linkedTagCount = 0
      for (toDoID, toDo) in syncedToDosByCloudID {
         let remoteTags = groupedTagIDsByToDoID[toDoID, default: []]
            .compactMap { syncedTagsByCloudID[$0.tagID] }
         linkedTagCount += remoteTags.count
         toDo.setSelectedTags(remoteTags)
         if let record = activeToDoRecordsByID[toDoID] {
            let remoteUpdatedAt = remoteTimestamp(createdAt: record.createdAt, updatedAt: record.updatedAt)
            toDo.updatedAt = remoteUpdatedAt
            toDo.lastSyncedUpdatedAt = remoteUpdatedAt
         }
      }
      Self.logSync("Supabase linked remote tags locally: todos=\(syncedToDosByCloudID.count), linkedTags=\(linkedTagCount), bodyApplied=\(remoteAppliedToDoIDs.count)")

      await Task.yield()

      for record in activeNanoDoRecords {
         guard let parentToDo = syncedToDosByCloudID[record.todoID] else { continue }
         let existingNanoDo = localNanoDosByCloudID[record.id]
         let nanoDo = existingNanoDo ?? NanoDo(
            task: record.task,
            createdAt: record.createdAt ?? .now,
            updatedAt: record.updatedAt ?? record.createdAt,
            dueDate: record.dueAt,
            isDone: record.isDone,
            toDo: parentToDo,
            tag: record.tagID.flatMap { syncedTagsByCloudID[$0] } ?? parentToDo.effectiveTags.first,
            cloudID: record.id,
            ownerUserID: record.userID
         )
         if nanoDo.modelContext == nil {
            context.insert(nanoDo)
         }
         guard existingNanoDo == nil || shouldApplyRemote(
            localUpdatedAt: nanoDo.syncUpdatedAt,
            remoteCreatedAt: record.createdAt,
            remoteUpdatedAt: record.updatedAt
         ) else {
            continue
         }
         nanoDo.cloudID = record.id
         nanoDo.ownerUserID = record.userID
         nanoDo.task = record.task
         if let createdAt = record.createdAt {
            nanoDo.createdAt = createdAt
         }
         nanoDo.dueDate = record.dueAt
         nanoDo.isDone = record.isDone
         nanoDo.toDo = parentToDo
         nanoDo.tag = record.tagID.flatMap { syncedTagsByCloudID[$0] } ?? parentToDo.effectiveTags.first
         nanoDo.updatedAt = remoteTimestamp(createdAt: record.createdAt, updatedAt: record.updatedAt)
      }

      if repairDuplicateTags(in: context, ownerUserID: ownerUserID) {
         await Task.yield()
      }
      try context.save()
      return RemoteApplyResult(appliedToDoCount: remoteAppliedToDoIDs.count, deletedToDoCount: 0)
   }

   private func canonicalRemoteTags(_ records: [SupabaseTagRecord]) -> [SupabaseTagRecord] {
      Dictionary(grouping: records, by: {
         TagIdentityKey(ownerUserID: $0.userID, normalizedName: Tag.normalizeName($0.name))
      })
         .compactMap { _, duplicates in
            duplicates.sorted { lhs, rhs in
               remoteTimestamp(createdAt: lhs.createdAt, updatedAt: lhs.updatedAt)
               > remoteTimestamp(createdAt: rhs.createdAt, updatedAt: rhs.updatedAt)
            }
            .first
         }
   }

   private func mapDuplicateRemoteTagIDs(
      _ records: [SupabaseTagRecord],
      canonicalRecords: [SupabaseTagRecord],
      into syncedTagsByCloudID: inout [UUID: Tag]
   ) {
      let canonicalIDByName = Dictionary(
         canonicalRecords.map {
            (TagIdentityKey(ownerUserID: $0.userID, normalizedName: Tag.normalizeName($0.name)), $0.id)
         },
         uniquingKeysWith: { existing, _ in existing }
      )

      for record in records {
         guard syncedTagsByCloudID[record.id] == nil,
               let canonicalID = canonicalIDByName[
                  TagIdentityKey(ownerUserID: record.userID, normalizedName: Tag.normalizeName(record.name))
               ],
               let canonicalTag = syncedTagsByCloudID[canonicalID]
         else { continue }

         syncedTagsByCloudID[record.id] = canonicalTag
      }
   }

   private func remoteChangeFeedbackMessage(for result: RemoteApplyResult) -> String {
      if result.deletedToDoCount > 0, result.appliedToDoCount == 0 {
         if result.deletedToDoCount == 1 {
            return String(localized: "Deleted on another device.")
         }

         return String(
            format: String(localized: "%@ deletes synced."),
            AppLocalization.numberString(result.deletedToDoCount)
         )
      }

      if result.changedToDoCount == 1 {
         return String(localized: "Synced from another device.")
      }

      return String(
         format: String(localized: "%@ updates synced."),
         AppLocalization.numberString(result.changedToDoCount)
      )
   }

   private func remoteDeletedToDoCount(remoteSnapshot: SupabaseRemoteSnapshot, localSnapshot: LocalSnapshot) -> Int {
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      guard !tombstonedToDoIDs.isEmpty else { return 0 }
      return localSnapshot.toDos.filter { toDo in
         toDo.cloudID.map { tombstonedToDoIDs.contains($0) } ?? false
      }.count
   }

   @discardableResult
   private func applyRemoteTombstones(
      _ remoteSnapshot: SupabaseRemoteSnapshot,
      to localSnapshot: LocalSnapshot,
      in context: ModelContext
   ) -> Bool {
      let tombstonedTagIDs = remoteSnapshot.tombstonedIDs(for: .tags)
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let tombstonedNanoDoIDs = remoteSnapshot.tombstonedIDs(for: .nanoDos)
      var didChange = false

      for nanoDo in localSnapshot.nanoDos where nanoDo.cloudID.map({ tombstonedNanoDoIDs.contains($0) }) ?? false {
         context.delete(nanoDo)
         didChange = true
      }

      for toDo in localSnapshot.toDos where toDo.cloudID.map({ tombstonedToDoIDs.contains($0) }) ?? false {
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
            for: toDo,
            in: context,
            recordsSyncTombstone: false
         )
         context.delete(toDo)
         didChange = true
      }

      for tag in localSnapshot.tags where tag.cloudID.map({ tombstonedTagIDs.contains($0) }) ?? false {
         context.delete(tag)
         didChange = true
      }

      return didChange
   }

   private func remoteTimestamp(createdAt: Date?, updatedAt: Date?) -> Date {
      updatedAt ?? createdAt ?? .distantPast
   }

   private func remoteToDoStateSummary(_ records: [SupabaseToDoRecord]) -> String {
      let counts = Dictionary(grouping: records, by: \.lifecycleState)
         .mapValues(\.count)

      return ToDoState.allCases
         .map { "\($0.rawValue)=\(counts[$0.rawValue, default: 0])" }
         .joined(separator: ",")
   }

   private func shouldApplyRemote(localUpdatedAt: Date, remoteCreatedAt: Date?, remoteUpdatedAt: Date?) -> Bool {
      remoteTimestamp(createdAt: remoteCreatedAt, updatedAt: remoteUpdatedAt) > localUpdatedAt
   }

   private func shouldUploadLocal(localUpdatedAt: Date, remoteCreatedAt: Date?, remoteUpdatedAt: Date?) -> Bool {
      localUpdatedAt > remoteTimestamp(createdAt: remoteCreatedAt, updatedAt: remoteUpdatedAt)
   }

   private func hasTwoSidedToDoConflict(localToDo: ToDo, remoteTimestamp: Date) -> Bool {
      let baseTimestamp = localToDo.lastSyncedUpdatedAt ?? localToDo.createdAt
      let localChangedSinceBase = localToDo.updatedAt != nil && localToDo.syncUpdatedAt > baseTimestamp
      let remoteChangedSinceBase = remoteTimestamp > baseTimestamp
      return localChangedSinceBase
      && remoteChangedSinceBase
      && abs(localToDo.syncUpdatedAt.timeIntervalSince(remoteTimestamp)) > 0.001
   }

   private func markUploadedToDos(_ uploadedToDoIDs: Set<UUID>, in snapshot: LocalSnapshot) {
      guard !uploadedToDoIDs.isEmpty else { return }
      for toDo in snapshot.toDos where toDo.cloudID.map({ uploadedToDoIDs.contains($0) }) ?? false {
         toDo.lastSyncedUpdatedAt = toDo.syncUpdatedAt
      }
   }

   private func firstLocalRecordByCloudID<Record: PersistentModel>(_ records: [Record]) -> [UUID: Record] where Record: AnyObject {
      var recordsByCloudID: [UUID: Record] = [:]

      for record in records {
         let cloudID: UUID?
         switch record {
         case let tag as Tag:
            cloudID = tag.cloudID
         case let toDo as ToDo:
            cloudID = toDo.cloudID
         case let nanoDo as NanoDo:
            cloudID = nanoDo.cloudID
         default:
            cloudID = nil
         }

         guard let cloudID, recordsByCloudID[cloudID] == nil else { continue }
         recordsByCloudID[cloudID] = record
      }

      return recordsByCloudID
   }

   private func upsertLocalSnapshot(
      _ snapshot: LocalSnapshot,
      for userID: UUID,
      remoteSnapshot: SupabaseRemoteSnapshot
   ) async throws -> LocalUploadResult {
      let defaultTagNames = Set(Tag.defaultTagNames)
      let tombstonedTagIDs = remoteSnapshot.tombstonedIDs(for: .tags)
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let tombstonedNanoDoIDs = remoteSnapshot.tombstonedIDs(for: .nanoDos)
      let remoteTagsByID = Dictionary(
         remoteSnapshot.tags
            .filter { !tombstonedTagIDs.contains($0.id) }
            .map { ($0.id, $0) },
         uniquingKeysWith: { _, latest in latest }
      )
      let remoteToDosByID = Dictionary(
         remoteSnapshot.toDos
            .filter { !tombstonedToDoIDs.contains($0.id) }
            .map { ($0.id, $0) },
         uniquingKeysWith: { _, latest in latest }
      )
      let remoteNanoDosByID = Dictionary(
         remoteSnapshot.nanoDos
            .filter {
               !tombstonedNanoDoIDs.contains($0.id)
               && !tombstonedToDoIDs.contains($0.todoID)
            }
            .map { ($0.id, $0) },
         uniquingKeysWith: { _, latest in latest }
      )
      let conflictedToDoIDs = Set(snapshot.conflicts.compactMap(\.recordID))

      func makeTagPayloads() -> [SupabaseTagUpsertPayload] {
         snapshot.tags.compactMap { tag -> SupabaseTagUpsertPayload? in
            guard let cloudID = tag.cloudID else { return nil }
            guard !tombstonedTagIDs.contains(cloudID) else { return nil }
            guard let ownerUserID = tag.ownerUserID, ownerUserID == userID else { return nil }
            if let remote = remoteTagsByID[cloudID],
               !shouldUploadLocal(
                  localUpdatedAt: tag.syncUpdatedAt,
                  remoteCreatedAt: remote.createdAt,
                  remoteUpdatedAt: remote.updatedAt
               ) {
               return nil
            }
            return SupabaseTagUpsertPayload(
               id: cloudID,
               userID: ownerUserID,
               name: Tag.normalizeName(tag.name),
               isDefault: defaultTagNames.contains(Tag.normalizeName(tag.name)),
               createdAt: tag.createdAt,
               updatedAt: tag.syncUpdatedAt
            )
         }
      }

      var tagPayloads = makeTagPayloads()

      var toDoPayloads: [SupabaseToDoUpsertPayload] = []
      var sharedToDoUpdates: [(id: UUID, payload: SupabaseToDoUpdatePayload)] = []
      var skippedStaleSharedToDoCount = 0
      for toDo in snapshot.toDos {
         guard let cloudID = toDo.cloudID else { continue }
         guard !tombstonedToDoIDs.contains(cloudID) else { continue }
         guard !conflictedToDoIDs.contains(cloudID) else { continue }
         let remote = remoteToDosByID[cloudID]
         if let remote,
            !shouldUploadLocal(
               localUpdatedAt: toDo.syncUpdatedAt,
               remoteCreatedAt: remote.createdAt,
               remoteUpdatedAt: remote.updatedAt
            ) {
            continue
         }
         let payload = SupabaseToDoUpsertPayload(
            id: cloudID,
            userID: remote?.userID ?? toDo.ownerUserID ?? userID,
            collabID: toDo.collabID,
            task: toDo.task,
            notes: toDo.notes,
            isDone: toDo.isDone,
            createdAt: toDo.createdAt,
            updatedAt: toDo.syncUpdatedAt,
            completedAt: toDo.completionActivityDate,
            lifecycleState: toDo.lifecycleState.rawValue,
            reminderIntent: toDo.reminderIntent.rawValue,
            dueAt: toDo.dueDate,
            dueTimeZone: toDo.dueDate == nil ? nil : TimeZone.current.identifier,
            isRecurring: toDo.isRecurring,
            recurrenceUnit: toDo.recurrenceUnit?.rawValue,
            recurrenceInterval: toDo.recurrenceInterval,
            recurrenceMode: toDo.recurrenceMode?.rawValue,
            recurrenceCount: toDo.recurrenceMode == .finite ? toDo.recurrenceCount : nil,
            recurrenceAnchorAt: toDo.recurrenceAnchorDate ?? toDo.dueDate,
            recurrenceEndAt: toDo.recurrenceEndDate,
            completeWhenAllNanoDosDone: toDo.completeWhenAllNanoDosDone,
            sortPosition: nil,
            trashedAt: toDo.lifecycleState == .trashed
               ? (toDo.trashedAt ?? toDo.syncUpdatedAt)
               : nil
         )
         switch SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: remote?.userID,
            localOwnerID: toDo.ownerUserID,
            actingUserID: userID
         ) {
         case .insertOrUpsert:
            toDoPayloads.append(payload)
         case .authorizedUpdate:
            sharedToDoUpdates.append((cloudID, SupabaseToDoUpdatePayload(payload)))
         case .skipUnauthorizedInsert:
            skippedStaleSharedToDoCount += 1
         }
      }

      var nanoDoPayloads: [SupabaseNanoDoUpsertPayload] = []
      var sharedNanoDoUpdates: [(id: UUID, payload: SupabaseNanoDoUpdatePayload)] = []
      var skippedStaleSharedNanoDoCount = 0
      var skippedTombstonedNanoDoCount = 0
      var skippedMissingParentNanoDoCount = 0
      let activeRemoteToDoIDs = Set(remoteToDosByID.keys)
      let insertedToDoIDs = Set(toDoPayloads.map(\.id))
      for nanoDo in snapshot.nanoDos {
         guard let cloudID = nanoDo.cloudID,
               let toDoID = nanoDo.toDo?.cloudID else { continue }
         switch SupabaseNanoDoUploadDisposition.resolve(
            isNanoDoTombstoned: tombstonedNanoDoIDs.contains(cloudID),
            isParentTombstoned: tombstonedToDoIDs.contains(toDoID),
            parentExistsRemotely: activeRemoteToDoIDs.contains(toDoID),
            parentWillBeInserted: insertedToDoIDs.contains(toDoID)
         ) {
         case .upload:
            break
         case .skipTombstonedRecord:
            skippedTombstonedNanoDoCount += 1
            continue
         case .skipMissingParent:
            skippedMissingParentNanoDoCount += 1
            continue
         }
         let remote = remoteNanoDosByID[cloudID]
         if let remote,
            !shouldUploadLocal(
               localUpdatedAt: nanoDo.syncUpdatedAt,
               remoteCreatedAt: remote.createdAt,
               remoteUpdatedAt: remote.updatedAt
            ) {
            continue
         }
         let payload = SupabaseNanoDoUpsertPayload(
            id: cloudID,
            todoID: toDoID,
            userID: remote?.userID ?? nanoDo.ownerUserID ?? userID,
            task: nanoDo.task,
            isDone: nanoDo.isDone,
            tagID: nanoDo.tag?.cloudID,
            dueAt: nanoDo.dueDate,
            createdAt: nanoDo.createdAt,
            updatedAt: nanoDo.syncUpdatedAt
         )
         switch SupabaseSyncWriteStrategy.resolve(
            remoteOwnerID: remote?.userID,
            localOwnerID: nanoDo.ownerUserID,
            actingUserID: userID
         ) {
         case .insertOrUpsert:
            nanoDoPayloads.append(payload)
         case .authorizedUpdate:
            sharedNanoDoUpdates.append((cloudID, SupabaseNanoDoUpdatePayload(payload)))
         case .skipUnauthorizedInsert:
            skippedStaleSharedNanoDoCount += 1
         }
      }

      if skippedStaleSharedToDoCount > 0 || skippedStaleSharedNanoDoCount > 0 {
         AppLog.info(
            "Skipped stale shared inserts without a server record: todos=\(skippedStaleSharedToDoCount), nanodos=\(skippedStaleSharedNanoDoCount)",
            logger: AppLog.sync
         )
      }
      if skippedTombstonedNanoDoCount > 0 || skippedMissingParentNanoDoCount > 0 {
         AppLog.info(
            "Skipped NanoDo uploads that cannot satisfy parent authorization: tombstoned=\(skippedTombstonedNanoDoCount), missingParent=\(skippedMissingParentNanoDoCount)",
            logger: AppLog.sync
         )
      }

      func uploadTagPayloads(_ payloads: [SupabaseTagUpsertPayload]) async throws {
         try requireActiveAccount(for: userID)
         let ownedRemotePayloads = payloads.filter { payload in
            SupabaseTagWriteDisposition.resolve(
               remoteOwnerID: remoteTagsByID[payload.id]?.userID,
               actingUserID: userID
            ) == .upsert
         }
         let newOrUnseenPayloads = payloads.filter { payload in
            SupabaseTagWriteDisposition.resolve(
               remoteOwnerID: remoteTagsByID[payload.id]?.userID,
               actingUserID: userID
            ) == .insert
         }

         if !ownedRemotePayloads.isEmpty {
            try requireActiveAccount(for: userID)
            try await supabase
               .from("tags")
               .upsert(ownedRemotePayloads, onConflict: "id")
               .execute()
         }

         // An ID absent from the RLS-filtered snapshot cannot safely be
         // treated as an update. Insert it instead; an inaccessible collision
         // then becomes a recoverable uniqueness failure rather than an RLS
         // update denial.
         if !newOrUnseenPayloads.isEmpty {
            try requireActiveAccount(for: userID)
            try await supabase
               .from("tags")
               .insert(newOrUnseenPayloads, returning: .minimal)
               .execute()
         }
      }

      if !tagPayloads.isEmpty {
         do {
            try await uploadTagPayloads(tagPayloads)
         } catch {
            guard SupabaseTagUploadRecoveryDisposition.resolve(
               errorDescription: "\(String(describing: error))\n\(error.localizedDescription)"
            ) == .retryWithFreshIDs else {
               AppLog.error(
                  "Tag sync failed: \(error.localizedDescription)",
                  logger: AppLog.sync
               )
               throw error
            }

            let unseenTagIDs = Set<UUID>(
               tagPayloads.compactMap { payload in
                  guard remoteTagsByID[payload.id]?.userID != userID else { return nil }
                  return payload.id
               }
            )
            var didReassignIDs = false
            for tag in snapshot.tags where tag.ownerUserID == userID {
               guard let cloudID = tag.cloudID, unseenTagIDs.contains(cloudID) else { continue }
               tag.cloudID = UUID()
               didReassignIDs = true
            }

            guard didReassignIDs else {
               AppLog.error(
                  "Tag sync failed and no owned tag IDs were available for collision recovery: \(error.localizedDescription)",
                  logger: AppLog.sync
               )
               throw error
            }

            tagPayloads = makeTagPayloads()
            do {
               try await uploadTagPayloads(tagPayloads)
               AppLog.info(
                  "Supabase replaced colliding local tag IDs and retried the upload.",
                  logger: AppLog.sync
               )
            } catch {
               AppLog.error(
                  "Tag sync failed after collision recovery: \(error.localizedDescription)",
                  logger: AppLog.sync
               )
               throw error
            }
         }
      }

      if !toDoPayloads.isEmpty {
         try requireActiveAccount(for: userID)
         try await supabase
            .from("todos")
            .upsert(toDoPayloads, onConflict: "id")
            .execute()
      }

      for update in sharedToDoUpdates {
         try requireActiveAccount(for: userID)
         try await supabase
            .from("todos")
            .update(update.payload)
            .eq("id", value: update.id)
            .execute()
      }

      if !nanoDoPayloads.isEmpty {
         try requireActiveAccount(for: userID)
         try await supabase
            .from("nanodos")
            .upsert(nanoDoPayloads, onConflict: "id")
            .execute()
      }

      for update in sharedNanoDoUpdates {
         try requireActiveAccount(for: userID)
         try await supabase
            .from("nanodos")
            .update(update.payload)
            .eq("id", value: update.id)
            .execute()
      }

      let toDoTagPairs = Array(localToDoTagPairs(from: snapshot).subtracting(remoteToDoTagPairs(from: remoteSnapshot)))
      if !toDoTagPairs.isEmpty {
         AppLog.info(
            "Preparing \(toDoTagPairs.count) toDo-tag relationship payloads for user \(userID)",
            logger: AppLog.sync
         )
         try requireActiveAccount(for: userID)
         try await upsertToDoTagPairs(toDoTagPairs)
      }

      return LocalUploadResult(
         uploadedToDoIDs: Set(toDoPayloads.map(\.id)).union(sharedToDoUpdates.map(\.id))
      )
   }

   private func insertMissingToDoTagPairs(localSnapshot: LocalSnapshot, remoteSnapshot: SupabaseRemoteSnapshot) async throws {
      let pairsToInsert = localToDoTagPairs(from: localSnapshot).subtracting(remoteToDoTagPairs(from: remoteSnapshot))
      try await upsertToDoTagPairs(Array(pairsToInsert))
   }

   private func reconcileToDoTags(localSnapshot: LocalSnapshot, remoteSnapshot: SupabaseRemoteSnapshot) async throws {
      let localPairs = localToDoTagPairs(from: localSnapshot)
      let remotePairs = remoteToDoTagPairs(from: remoteSnapshot)

      try await upsertToDoTagPairs(Array(localPairs.subtracting(remotePairs)))

      for pair in remotePairs.subtracting(localPairs) {
         try await supabase
            .from("todo_tags")
            .delete()
            .eq("todo_id", value: pair.todoID)
            .eq("tag_id", value: pair.tagID)
            .execute()
      }
   }

   private func localToDoTagPairs(from snapshot: LocalSnapshot) -> Set<SupabaseToDoTagUpsertPayload> {
      Set(snapshot.toDos.flatMap { toDo in
         guard let toDoID = toDo.cloudID else { return [SupabaseToDoTagUpsertPayload]() }
         return toDo.effectiveTags.compactMap { tag in
            guard let tagID = tag.cloudID else { return nil }
            return SupabaseToDoTagUpsertPayload(todoID: toDoID, tagID: tagID)
         }
      })
   }

   private func remoteToDoTagPairs(from snapshot: SupabaseRemoteSnapshot) -> Set<SupabaseToDoTagUpsertPayload> {
      Set(snapshot.toDoTags.map {
         SupabaseToDoTagUpsertPayload(todoID: $0.todoID, tagID: $0.tagID)
      })
   }

   private func upsertToDoTagPairs(_ pairs: [SupabaseToDoTagUpsertPayload]) async throws {
      guard !pairs.isEmpty else { return }

      try await supabase
         .from("todo_tags")
         .upsert(pairs, onConflict: "todo_id,tag_id")
         .execute()
   }

   private func refreshPlatformSurfaces(from context: ModelContext) {
      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
      #if os(macOS)
      NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
      #else
      LiveActivityService.shared.refresh(from: context)
      #endif
   }

   private func upsertPendingTombstones(for userID: UUID) async throws {
      let tombstones = SyncTombstoneStore.pendingTombstones(for: userID)
      guard !tombstones.isEmpty else { return }

      try await upsertTombstones(tombstones.map(SupabaseTombstoneUpsertPayload.init))
      SyncTombstoneStore.removeSyncedTombstones(tombstones)
   }

   private func upsertTombstones(_ tombstones: [SupabaseTombstoneUpsertPayload]) async throws {
      guard !tombstones.isEmpty else { return }

      try await supabase
         .from("sync_tombstones")
         .upsert(tombstones, onConflict: "user_id,record_table,record_id")
         .execute()
   }

   private func deleteTombstonedRemoteRecords(remoteSnapshot: SupabaseRemoteSnapshot) async throws {
      let tombstonedNanoDoIDs = remoteSnapshot.tombstonedIDs(for: .nanoDos)
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let tombstonedTagIDs = remoteSnapshot.tombstonedIDs(for: .tags)

      for nanoDoID in Set(remoteSnapshot.nanoDos.map(\.id)).intersection(tombstonedNanoDoIDs) {
         try await deleteRemoteRecord(table: .nanoDos, id: nanoDoID)
      }

      for toDoID in Set(remoteSnapshot.toDos.map(\.id)).intersection(tombstonedToDoIDs) {
         try await deleteRemoteRecord(table: .toDos, id: toDoID)
      }

      for tagID in Set(remoteSnapshot.tags.map(\.id)).intersection(tombstonedTagIDs) {
         try await deleteRemoteRecord(table: .tags, id: tagID)
      }
   }

   private func deleteRemoteRecord(table: SyncRecordTable, id: UUID) async throws {
      try await supabase
         .from(table.rawValue)
         .delete()
         .eq("id", value: id)
         .execute()
   }
}
