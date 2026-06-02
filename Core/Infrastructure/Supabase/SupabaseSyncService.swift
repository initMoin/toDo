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
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date?
   let updatedAt: Date?
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
   let sortPosition: Double?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
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
      case sortPosition = "sort_position"
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

private struct SupabaseTombstoneRecord: Codable, Hashable {
   let userID: UUID
   let recordTable: String
   let recordID: UUID
   let deletedAt: Date

   enum CodingKeys: String, CodingKey {
      case userID = "user_id"
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
   let task: String
   let notes: String
   let isDone: Bool
   let createdAt: Date
   let updatedAt: Date
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
   let sortPosition: Double?

   enum CodingKeys: String, CodingKey {
      case id
      case userID = "user_id"
      case task
      case notes
      case isDone = "is_done"
      case createdAt = "created_at"
      case updatedAt = "updated_at"
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
      case sortPosition = "sort_position"
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
   let recordTable: String
   let recordID: UUID
   let deletedAt: Date

   init(_ tombstone: SyncTombstone) {
      self.userID = tombstone.userID
      self.recordTable = tombstone.recordTable.rawValue
      self.recordID = tombstone.recordID
      self.deletedAt = tombstone.deletedAt
   }

   init(userID: UUID, recordTable: SyncRecordTable, recordID: UUID, deletedAt: Date = .now) {
      self.userID = userID
      self.recordTable = recordTable.rawValue
      self.recordID = recordID
      self.deletedAt = deletedAt
   }

   enum CodingKeys: String, CodingKey {
      case userID = "user_id"
      case recordTable = "record_table"
      case recordID = "record_id"
      case deletedAt = "deleted_at"
   }
}

#if DEBUG
enum SupabaseSchemaContractProbe {
   static func toDoPayload(task: String) -> some Encodable {
      SupabaseToDoUpsertPayload(
         id: UUID(),
         userID: UUID(),
         task: task,
         notes: "",
         isDone: false,
         createdAt: Date(timeIntervalSinceReferenceDate: 0),
         updatedAt: Date(timeIntervalSinceReferenceDate: 0),
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
         sortPosition: nil
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

   static func semanticDuplicateKeysMatchWhenOnlyCreatedAtDiffers() -> Bool {
      semanticKey(task: "Test1", dueAt: nil, recurrenceInterval: nil)
      == semanticKey(task: "Test1", dueAt: nil, recurrenceInterval: nil)
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
      dueAt: Int64?,
      recurrenceInterval: Int?
   ) -> ToDoSemanticDuplicateKey {
      ToDoSemanticDuplicateKey(
         task: task,
         notes: "",
         isDone: false,
         lifecycleState: ToDoState.active.rawValue,
         reminderIntent: ToDoReminderIntent.soft.rawValue,
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

   var hasContent: Bool {
      tags.isEmpty == false || toDos.isEmpty == false || nanoDos.isEmpty == false
   }
}

private struct LocalUploadResult {
   let uploadedToDoIDs: Set<UUID>
}

private struct RemoteApplyResult {
   let appliedToDoCount: Int
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
   let task: String
   let notes: String
   let isDone: Bool
   let lifecycleState: String
   let reminderIntent: String
   let dueAt: Int64?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceAnchorAt: Int64?
   let recurrenceEndAt: Int64?
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
   private var bootstrapTask: Task<Void, Never>?
   private var hasHydratedActiveUser = false
   private var isApplyingRemoteSnapshot = false
   private var needsLocalSyncAfterHydration = false
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
      hasHydratedActiveUser = false
      needsLocalSyncAfterHydration = false
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
      bootstrapTask?.cancel()
      bootstrapTask = nil
      hasHydratedActiveUser = false
      needsLocalSyncAfterHydration = false
      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = nil
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
      guard !isApplyingRemoteSnapshot else { return }

      SyncCoordinator.shared.beginSyncOperation(phase: .queuedLocalChanges)
      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = Task { [weak self] in
         guard let self else { return }
         try? await Task.sleep(nanoseconds: 800_000_000)
         guard !Task.isCancelled else { return }
         await self.pushLocalSnapshot(for: activeUserID)
      }
   }

   func flushLocalSync(for userID: UUID) async {
      guard activeUserID == userID, modelContainer != nil, hasHydratedActiveUser, !isApplyingRemoteSnapshot else { return }

      pendingLocalSyncTask?.cancel()
      pendingLocalSyncTask = nil
      await pushLocalSnapshot(for: userID)
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
      let userFilter = RealtimePostgresFilter.eq("user_id", value: userID.uuidString.lowercased())
      let streams = [
         channel.postgresChange(AnyAction.self, schema: "public", table: "todos", filter: userFilter),
         channel.postgresChange(AnyAction.self, schema: "public", table: "tags", filter: userFilter),
         channel.postgresChange(AnyAction.self, schema: "public", table: "nanodos", filter: userFilter),
         channel.postgresChange(AnyAction.self, schema: "public", table: "sync_tombstones", filter: userFilter)
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

   private func bootstrapLocalCache(for userID: UUID) async -> Bool {
      guard let modelContainer else {
         Self.logSync("Supabase bootstrap local cache skipped: model container is missing.")
         return false
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

         let unownedSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: nil)
         SyncCoordinator.shared.updateSyncPhase(.uploadingPendingDeletes)
         try await upsertPendingTombstones(for: userID)
         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         try await deleteTombstonedRemoteRecords(remoteSnapshot: remoteSnapshot)
         let didCopyUnownedLocalData = try copyUnownedSnapshotToUserScopeIfNeeded(
            unownedSnapshot,
            userID: userID,
            remoteSnapshot: remoteSnapshot,
            in: context
         )
         if didCopyUnownedLocalData {
            try context.save()
         }

         let ownedLocalSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)

         if remoteSnapshot.isEmpty, ownedLocalSnapshot.hasContent {
            if ensureOwnershipAndCloudIDs(in: ownedLocalSnapshot, userID: userID) {
               try context.save()
            }
            SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
            let uploadResult = try await upsertLocalSnapshot(ownedLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
            markUploadedToDos(uploadResult.uploadedToDoIDs, in: ownedLocalSnapshot)
            try context.save()
            SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
            try await insertMissingToDoTagPairs(localSnapshot: ownedLocalSnapshot, remoteSnapshot: remoteSnapshot)

            hasHydratedActiveUser = true
            needsLocalSyncAfterHydration = false
            NotificationManager.shared.scheduleRefresh()
            WidgetSnapshotService.shared.writeSnapshot(from: context)
            LiveActivityService.shared.refresh(from: context)
            SyncCoordinator.shared.completeSyncOperation()
            return true
         }

         if didCopyUnownedLocalData {
            var mergedLocalSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
            let didRepairMergedTags = repairDuplicateTags(in: context, ownerUserID: userID)
            let didAlignTagIDs = alignTagCloudIDs(localSnapshot: mergedLocalSnapshot, remoteSnapshot: remoteSnapshot)
            if didRepairMergedTags || didAlignTagIDs {
               try context.save()
               mergedLocalSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
            }

            SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
            let uploadResult = try await upsertLocalSnapshot(mergedLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
            markUploadedToDos(uploadResult.uploadedToDoIDs, in: mergedLocalSnapshot)
            try context.save()
            SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
            try await insertMissingToDoTagPairs(localSnapshot: mergedLocalSnapshot, remoteSnapshot: remoteSnapshot)

            SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
            let mergedRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
            isApplyingRemoteSnapshot = true
            defer { isApplyingRemoteSnapshot = false }

            SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
            try await apply(remoteSnapshot: mergedRemoteSnapshot, in: context, ownerUserID: userID)
            hasHydratedActiveUser = true
            NotificationManager.shared.scheduleRefresh()
            WidgetSnapshotService.shared.writeSnapshot(from: context)
            LiveActivityService.shared.refresh(from: context)
            SyncCoordinator.shared.completeSyncOperation()
            return true
         }

         isApplyingRemoteSnapshot = true
         do {
            defer { isApplyingRemoteSnapshot = false }
            SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
            try await apply(remoteSnapshot: remoteSnapshot, in: context, ownerUserID: userID)
         }

         var reconciledLocalSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
         if ensureOwnershipAndCloudIDs(in: reconciledLocalSnapshot, userID: userID) {
            try context.save()
            reconciledLocalSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
         }
         SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
         let uploadResult = try await upsertLocalSnapshot(reconciledLocalSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
         markUploadedToDos(uploadResult.uploadedToDoIDs, in: reconciledLocalSnapshot)
         try context.save()
         SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
         try await reconcileToDoTags(localSnapshot: reconciledLocalSnapshot, remoteSnapshot: remoteSnapshot)

         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let reconciledRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }
         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         try await apply(remoteSnapshot: reconciledRemoteSnapshot, in: context, ownerUserID: userID)

         hasHydratedActiveUser = true
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         SyncCoordinator.shared.completeSyncOperation()
         return true
      } catch {
         if error is CancellationError { return false }
         AppLog.error("Supabase sync bootstrap failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
         return false
      }
   }

   private func pushLocalSnapshot(for userID: UUID) async {
      guard activeUserID == userID, let modelContainer else { return }
      guard !isPushingLocalSnapshot else { return }

      do {
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
         var localSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
         let didAssignCloudIDs = ensureOwnershipAndCloudIDs(in: localSnapshot, userID: userID)
         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         let didApplyRemoteTombstones = applyRemoteTombstones(remoteSnapshot, to: localSnapshot, in: context)
         let didAlignTagIDs = alignTagCloudIDs(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         if didRepairTags || didRepairToDos || didAssignCloudIDs || didApplyRemoteTombstones || didAlignTagIDs {
            try context.save()
            localSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
            didRepairTags = false
         }

         SyncCoordinator.shared.updateSyncPhase(.uploadingPendingDeletes)
         try await upsertPendingTombstones(for: userID)
         try await deleteTombstonedRemoteRecords(remoteSnapshot: remoteSnapshot)
         SyncCoordinator.shared.updateSyncPhase(.sendingLocalChanges)
         let uploadResult = try await upsertLocalSnapshot(localSnapshot, for: userID, remoteSnapshot: remoteSnapshot)
         markUploadedToDos(uploadResult.uploadedToDoIDs, in: localSnapshot)
         try context.save()
         SyncCoordinator.shared.updateSyncPhase(.reconcilingRelationships)
         try await reconcileToDoTags(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)

         SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
         let refreshedRemoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }
         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         try await apply(remoteSnapshot: refreshedRemoteSnapshot, in: context, ownerUserID: userID)
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         SyncCoordinator.shared.completeSyncOperation()
      } catch {
         if error is CancellationError { return }
         AppLog.error("Supabase local push failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
      }
   }

   private func pullRemoteSnapshot(for userID: UUID, showsRemoteChangeFeedback: Bool = false) async {
      guard activeUserID == userID, let modelContainer else { return }

      do {
         SyncCoordinator.shared.beginSyncOperation(phase: .loadingRemoteChanges)
         let context = modelContainer.mainContext
         let localSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: userID)
         let remoteSnapshot = try await fetchRemoteSnapshot(for: userID)
         let didApplyRemoteTombstones = applyRemoteTombstones(remoteSnapshot, to: localSnapshot, in: context)
         let didAlignTagIDs = alignTagCloudIDs(localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
         if didApplyRemoteTombstones || didAlignTagIDs {
            try context.save()
         }

         isApplyingRemoteSnapshot = true
         defer { isApplyingRemoteSnapshot = false }

         SyncCoordinator.shared.updateSyncPhase(.applyingRemoteChanges)
         let applyResult = try await apply(remoteSnapshot: remoteSnapshot, in: context, ownerUserID: userID)
         if showsRemoteChangeFeedback, applyResult.appliedToDoCount > 0 {
            SyncCoordinator.shared.showTransientFeedback(
               title: String(localized: "toDō updated"),
               message: remoteChangeFeedbackMessage(for: applyResult.appliedToDoCount),
               style: .success
            )
         }
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context)
         SyncCoordinator.shared.completeSyncOperation()
      } catch {
         if error is CancellationError { return }
         AppLog.error("Supabase remote refresh failed: \(error)", logger: AppLog.sync)
         SyncCoordinator.shared.failSyncOperation(error)
      }
   }

   private func fetchRemoteSnapshot(for userID: UUID) async throws -> SupabaseRemoteSnapshot {
      let remoteSnapshot = try await fetchRawRemoteSnapshot(for: userID)
      guard try await cleanupDuplicateRemoteToDos(in: remoteSnapshot) else {
         return remoteSnapshot
      }
      SyncCoordinator.shared.updateSyncPhase(.loadingRemoteChanges)
      return try await fetchRawRemoteSnapshot(for: userID)
   }

   private func fetchRawRemoteSnapshot(for userID: UUID) async throws -> SupabaseRemoteSnapshot {
      async let tags: [SupabaseTagRecord] = supabase
         .from("tags")
         .select()
         .eq("user_id", value: userID)
         .execute()
         .value

      async let toDos: [SupabaseToDoRecord] = supabase
         .from("todos")
         .select()
         .eq("user_id", value: userID)
         .execute()
         .value

      async let nanoDos: [SupabaseNanoDoRecord] = supabase
         .from("nanodos")
         .select()
         .eq("user_id", value: userID)
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
         .eq("user_id", value: userID)
         .execute()
         .value

      let resolvedToDos = try await toDos
      let resolvedTags = try await tags
      let resolvedNanoDos = try await nanoDos
      let resolvedToDoTags = try await toDoTags
      let resolvedTombstones = try await tombstones

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
   private func cleanupDuplicateRemoteToDos(in remoteSnapshot: SupabaseRemoteSnapshot) async throws -> Bool {
      let tombstonedToDoIDs = remoteSnapshot.tombstonedIDs(for: .toDos)
      let activeToDos = remoteSnapshot.toDos.filter { !tombstonedToDoIDs.contains($0.id) }
      guard activeToDos.count > 1 else { return false }

      let groupedToDos = Dictionary(grouping: activeToDos, by: remoteSemanticDuplicateKey(for:))
      let remoteChildCountsByToDoID = remoteToDoChildCounts(in: remoteSnapshot)
      var tombstones: [SupabaseTombstoneUpsertPayload] = []

      for duplicates in groupedToDos.values where duplicates.count > 1 {
         let canonical = duplicates.sorted {
            shouldPreferRemoteToDoAsCanonical($0, over: $1, childCountsByToDoID: remoteChildCountsByToDoID)
         }.first!

         for duplicate in duplicates where duplicate.id != canonical.id {
            tombstones.append(
               SupabaseTombstoneUpsertPayload(
                  userID: duplicate.userID,
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

   private func fetchLocalSnapshot(in context: ModelContext, ownerUserID: UUID?) throws -> LocalSnapshot {
      let tags = try context.fetch(FetchDescriptor<Tag>()).filter { $0.ownerUserID == ownerUserID }
      let toDos = try context.fetch(FetchDescriptor<ToDo>()).filter { $0.ownerUserID == ownerUserID }
      let nanoDos = try context.fetch(FetchDescriptor<NanoDo>()).filter { $0.ownerUserID == ownerUserID }
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
      let remoteTagsByName = Dictionary(grouping: remoteSnapshot.tags, by: \.name)
         .compactMapValues { records in
            records.sorted { lhs, rhs in
               remoteTimestamp(createdAt: lhs.createdAt, updatedAt: lhs.updatedAt) > remoteTimestamp(createdAt: rhs.createdAt, updatedAt: rhs.updatedAt)
            }.first
         }
      let remoteToDoIDsByDuplicateKey = Dictionary(grouping: remoteSnapshot.toDos, by: remoteSemanticDuplicateKey(for:))
         .compactMapValues { records in
            records.sorted { lhs, rhs in
               remoteTimestamp(createdAt: lhs.createdAt, updatedAt: lhs.updatedAt) > remoteTimestamp(createdAt: rhs.createdAt, updatedAt: rhs.updatedAt)
            }.first?.id
         }
      var ownedTagsByName: [String: Tag] = [:]
      for tag in ownedSnapshot.tags where ownedTagsByName[tag.displayName] == nil {
         ownedTagsByName[tag.displayName] = tag
      }
      var clonedTagsBySourceID: [PersistentIdentifier: Tag] = [:]
      var didChange = false

      for sourceTag in snapshot.tags {
         if let existingTag = ownedTagsByName[sourceTag.displayName] {
            clonedTagsBySourceID[sourceTag.id] = existingTag
            continue
         }

         let clonedTag = Tag(
            name: sourceTag.name,
            createdAt: sourceTag.createdAt,
            updatedAt: sourceTag.updatedAt,
            cloudID: sourceTag.cloudID ?? remoteTagsByName[sourceTag.displayName]?.id ?? UUID(),
            ownerUserID: userID
         )
         if sourceTag.cloudID == nil {
            sourceTag.cloudID = clonedTag.cloudID
         }
         context.insert(clonedTag)
         ownedTagsByName[sourceTag.displayName] = clonedTag
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
            nanoDos: [],
            tag: nil,
            tags: [],
            cloudID: sourceCloudID,
            ownerUserID: userID
         )
         context.insert(clonedToDo)
         clonedToDo.setSelectedTags(sourceToDo.effectiveTags.compactMap { clonedTagsBySourceID[$0.id] })
         clonedToDo.updatedAt = sourceToDo.updatedAt
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

      for tag in snapshot.tags where tag.cloudID == nil {
         tag.cloudID = UUID()
         didChange = true
      }
      for tag in snapshot.tags where tag.ownerUserID != userID {
         tag.ownerUserID = userID
         didChange = true
      }

      for toDo in snapshot.toDos where toDo.cloudID == nil {
         toDo.cloudID = UUID()
         didChange = true
      }
      for toDo in snapshot.toDos where toDo.ownerUserID != userID {
         toDo.ownerUserID = userID
         didChange = true
      }

      for nanoDo in snapshot.nanoDos where nanoDo.cloudID == nil {
         nanoDo.cloudID = UUID()
         didChange = true
      }
      for nanoDo in snapshot.nanoDos where nanoDo.ownerUserID != userID {
         nanoDo.ownerUserID = userID
         didChange = true
      }

      return didChange
   }

   @discardableResult
   private func repairDuplicateTags(in context: ModelContext, ownerUserID: UUID?) -> Bool {
      let tags = (try? fetchTags(in: context, ownerUserID: ownerUserID)) ?? []
      guard tags.count > 1 else { return false }

      let grouped = Dictionary(grouping: tags, by: \.displayName)
      var didChange = false

      for duplicates in grouped.values where duplicates.count > 1 {
         let canonical = duplicates.sorted {
            if $0.cloudID != nil, $1.cloudID == nil { return true }
            if $0.cloudID == nil, $1.cloudID != nil { return false }
            return $0.createdAt < $1.createdAt
         }.first!

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
      let toDos = (try? fetchToDos(in: context, ownerUserID: ownerUserID)) ?? []
      guard toDos.count > 1 else { return false }

      let grouped = Dictionary(grouping: toDos, by: semanticDuplicateKey(for:))
      var didChange = false

      for duplicates in grouped.values where duplicates.count > 1 {
         let canonical = duplicates.sorted(by: shouldPreferAsCanonical(_:over:)).first!

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
                  userID: duplicate.ownerUserID
               )
            }

            if canonical.effectiveTags.isEmpty, !duplicate.effectiveTags.isEmpty {
               canonical.setSelectedTags(duplicate.effectiveTags)
            }

            context.delete(duplicate)
            didChange = true
         }
      }

      return didChange
   }

   private func shouldPreferAsCanonical(_ lhs: ToDo, over rhs: ToDo) -> Bool {
      if lhs.cloudID != nil, rhs.cloudID == nil { return true }
      if lhs.cloudID == nil, rhs.cloudID != nil { return false }
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
         task: toDo.task,
         notes: toDo.notes,
         isDone: toDo.isDone,
         lifecycleState: toDo.lifecycleState.rawValue,
         reminderIntent: toDo.reminderIntent.rawValue,
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
         task: record.task,
         notes: record.notes,
         isDone: record.isDone,
         lifecycleState: record.lifecycleState,
         reminderIntent: record.reminderIntent,
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
      let remoteByName = Dictionary(grouping: remoteSnapshot.tags, by: \.name)
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
         guard let remoteRecord = remoteByName[tag.displayName] else { continue }
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
   private func apply(remoteSnapshot: SupabaseRemoteSnapshot, in context: ModelContext, ownerUserID: UUID) async throws -> RemoteApplyResult {
      let localSnapshot = try fetchLocalSnapshot(in: context, ownerUserID: ownerUserID)
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

      var syncedTagsByCloudID: [UUID: Tag] = [:]
      for record in activeTagRecords {
         let existingTag = localTagsByCloudID[record.id]
         let tag = existingTag ?? Tag(
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
            dueDate: record.dueAt,
            reminderIntent: ToDoReminderIntent(rawValue: record.reminderIntent) ?? .soft,
            lifecycleState: ToDoState(rawValue: record.lifecycleState) ?? .active,
            cloudID: record.id,
            ownerUserID: record.userID
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

      try context.save()
      return RemoteApplyResult(appliedToDoCount: remoteAppliedToDoIDs.count)
   }

   private func remoteChangeFeedbackMessage(for appliedToDoCount: Int) -> String {
      if appliedToDoCount == 1 {
         return String(localized: "Synced from another device.")
      }

      return String(
         format: String(localized: "%@ updates synced."),
         AppLocalization.numberString(appliedToDoCount)
      )
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
         SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
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
      let defaultTagNames = Set(TagManagementView.defaultTagNames)
      let remoteTagsByID = Dictionary(remoteSnapshot.tags.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      let remoteToDosByID = Dictionary(remoteSnapshot.toDos.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      let remoteNanoDosByID = Dictionary(remoteSnapshot.nanoDos.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
      let conflictedToDoIDs = Set(snapshot.conflicts.compactMap(\.recordID))

      let tagPayloads = snapshot.tags.compactMap { tag -> SupabaseTagUpsertPayload? in
         guard let cloudID = tag.cloudID else { return nil }
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
            userID: userID,
            name: tag.displayName,
            isDefault: defaultTagNames.contains(tag.displayName),
            createdAt: tag.createdAt,
            updatedAt: tag.syncUpdatedAt
         )
      }

      let toDoPayloads = snapshot.toDos.compactMap { toDo -> SupabaseToDoUpsertPayload? in
         guard let cloudID = toDo.cloudID else { return nil }
         guard !conflictedToDoIDs.contains(cloudID) else { return nil }
         if let remote = remoteToDosByID[cloudID],
            !shouldUploadLocal(
               localUpdatedAt: toDo.syncUpdatedAt,
               remoteCreatedAt: remote.createdAt,
               remoteUpdatedAt: remote.updatedAt
            ) {
            return nil
         }
         return SupabaseToDoUpsertPayload(
            id: cloudID,
            userID: userID,
            task: toDo.task,
            notes: toDo.notes,
            isDone: toDo.isDone,
            createdAt: toDo.createdAt,
            updatedAt: toDo.syncUpdatedAt,
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
            sortPosition: nil
         )
      }

      let nanoDoPayloads = snapshot.nanoDos.compactMap { nanoDo -> SupabaseNanoDoUpsertPayload? in
         guard let cloudID = nanoDo.cloudID,
               let toDoID = nanoDo.toDo?.cloudID else { return nil }
         if let remote = remoteNanoDosByID[cloudID],
            !shouldUploadLocal(
               localUpdatedAt: nanoDo.syncUpdatedAt,
               remoteCreatedAt: remote.createdAt,
               remoteUpdatedAt: remote.updatedAt
            ) {
            return nil
         }
         return SupabaseNanoDoUpsertPayload(
            id: cloudID,
            todoID: toDoID,
            userID: userID,
            task: nanoDo.task,
            isDone: nanoDo.isDone,
            tagID: nanoDo.tag?.cloudID,
            dueAt: nanoDo.dueDate,
            createdAt: nanoDo.createdAt,
            updatedAt: nanoDo.syncUpdatedAt
         )
      }

      if !tagPayloads.isEmpty {
         try await supabase
            .from("tags")
            .upsert(tagPayloads, onConflict: "id")
            .execute()
      }

      if !toDoPayloads.isEmpty {
         try await supabase
            .from("todos")
            .upsert(toDoPayloads, onConflict: "id")
            .execute()
      }

      if !nanoDoPayloads.isEmpty {
         try await supabase
            .from("nanodos")
            .upsert(nanoDoPayloads, onConflict: "id")
            .execute()
      }

      return LocalUploadResult(uploadedToDoIDs: Set(toDoPayloads.map(\.id)))
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
