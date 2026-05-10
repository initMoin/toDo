import Foundation
import SwiftData

enum SyncRecordTable: String, Codable, CaseIterable {
    case tags
    case toDos = "todos"
    case nanoDos = "nanodos"
}

struct SyncTombstone: Codable, Hashable {
    let userID: UUID
    let recordTable: SyncRecordTable
    let recordID: UUID
    let deletedAt: Date
}

enum SyncTombstoneStore {
    private static let storageKey = "pendingSyncTombstones"

    static func recordDelete(
        table: SyncRecordTable,
        recordID: UUID?,
        userID: UUID?,
        deletedAt: Date = .now,
        userDefaults: UserDefaults = .standard
    ) {
        guard let recordID, let userID else { return }

        var tombstones = pendingTombstones(userDefaults: userDefaults)
        tombstones.removeAll {
            $0.userID == userID
            && $0.recordTable == table
            && $0.recordID == recordID
        }
        tombstones.append(
            SyncTombstone(
                userID: userID,
                recordTable: table,
                recordID: recordID,
                deletedAt: deletedAt
            )
        )
        save(tombstones, userDefaults: userDefaults)
    }

    static func pendingTombstones(
        for userID: UUID? = nil,
        userDefaults: UserDefaults = .standard
    ) -> [SyncTombstone] {
        guard let data = userDefaults.data(forKey: storageKey),
              let tombstones = try? JSONDecoder().decode([SyncTombstone].self, from: data)
        else {
            return []
        }

        guard let userID else { return tombstones }
        return tombstones.filter { $0.userID == userID }
    }

    static func removeSyncedTombstones(
        _ syncedTombstones: [SyncTombstone],
        userDefaults: UserDefaults = .standard
    ) {
        guard !syncedTombstones.isEmpty else { return }

        let synced = Set(syncedTombstones)
        let remaining = pendingTombstones(userDefaults: userDefaults).filter { !synced.contains($0) }
        save(remaining, userDefaults: userDefaults)
    }

    private static func save(_ tombstones: [SyncTombstone], userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(tombstones) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

enum SyncConflictSeverity: String, Codable, CaseIterable {
    case warning
    case destructive
}

enum SyncConflictResolution {
    case keepDeviceVersion
    case useSyncedVersion
}

@Model
final class SyncConflict {
    var id: UUID = UUID()
    var userID: UUID? = nil
    var recordTableRaw: String = SyncRecordTable.toDos.rawValue
    var recordID: UUID? = nil
    var severityRaw: String = SyncConflictSeverity.warning.rawValue
    var title: String = ""
    var message: String = ""
    var localSummary: String = ""
    var syncedSummary: String = ""
    var localUpdatedAt: Date? = nil
    var syncedUpdatedAt: Date? = nil
    var syncedTask: String? = nil
    var syncedNotes: String? = nil
    var syncedIsDone: Bool = false
    var syncedLifecycleStateRaw: String = ToDoState.active.rawValue
    var syncedReminderIntentRaw: String = ToDoReminderIntent.soft.rawValue
    var syncedDueDate: Date? = nil
    var syncedRecurrenceUnitRaw: String? = nil
    var syncedRecurrenceIntervalValue: Int? = nil
    var syncedRecurrenceModeRaw: String? = nil
    var syncedRecurrenceCountValue: Int? = nil
    var syncedRecurrenceAnchorDate: Date? = nil
    var syncedRecurrenceEndDate: Date? = nil
    var createdAt: Date = Date()
    var resolvedAt: Date? = nil

    init(
        userID: UUID,
        recordID: UUID,
        severity: SyncConflictSeverity,
        title: String,
        message: String,
        localSummary: String,
        syncedSummary: String,
        localUpdatedAt: Date,
        syncedUpdatedAt: Date,
        syncedTask: String,
        syncedNotes: String,
        syncedIsDone: Bool,
        syncedLifecycleState: ToDoState,
        syncedReminderIntent: ToDoReminderIntent,
        syncedDueDate: Date?,
        syncedRecurrenceUnit: ToDoRecurrenceUnit?,
        syncedRecurrenceInterval: Int?,
        syncedRecurrenceMode: ToDoRecurrenceMode?,
        syncedRecurrenceCount: Int?,
        syncedRecurrenceAnchorDate: Date?,
        syncedRecurrenceEndDate: Date?
    ) {
        self.userID = userID
        self.recordID = recordID
        self.severityRaw = severity.rawValue
        self.title = title
        self.message = message
        self.localSummary = localSummary
        self.syncedSummary = syncedSummary
        self.localUpdatedAt = localUpdatedAt
        self.syncedUpdatedAt = syncedUpdatedAt
        self.syncedTask = syncedTask
        self.syncedNotes = syncedNotes
        self.syncedIsDone = syncedIsDone
        self.syncedLifecycleStateRaw = syncedLifecycleState.rawValue
        self.syncedReminderIntentRaw = syncedReminderIntent.rawValue
        self.syncedDueDate = syncedDueDate
        self.syncedRecurrenceUnitRaw = syncedRecurrenceUnit?.rawValue
        self.syncedRecurrenceIntervalValue = syncedRecurrenceInterval
        self.syncedRecurrenceModeRaw = syncedRecurrenceMode?.rawValue
        self.syncedRecurrenceCountValue = syncedRecurrenceCount
        self.syncedRecurrenceAnchorDate = syncedRecurrenceAnchorDate
        self.syncedRecurrenceEndDate = syncedRecurrenceEndDate
    }

    var recordTable: SyncRecordTable {
        SyncRecordTable(rawValue: recordTableRaw) ?? .toDos
    }

    var severity: SyncConflictSeverity {
        SyncConflictSeverity(rawValue: severityRaw) ?? .warning
    }

    var isResolved: Bool {
        resolvedAt != nil
    }

    var syncedLifecycleState: ToDoState {
        ToDoState(rawValue: syncedLifecycleStateRaw) ?? .active
    }

    var syncedReminderIntent: ToDoReminderIntent {
        ToDoReminderIntent(rawValue: syncedReminderIntentRaw) ?? .soft
    }
}

@MainActor
enum SyncConflictStore {
    static func unresolvedConflicts(in context: ModelContext, userID: UUID?) -> [SyncConflict] {
        let conflicts = (try? context.fetch(FetchDescriptor<SyncConflict>())) ?? []
        return conflicts
            .filter { !$0.isResolved && $0.userID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func unresolvedConflict(
        recordID: UUID,
        userID: UUID,
        in context: ModelContext
    ) -> SyncConflict? {
        unresolvedConflicts(in: context, userID: userID).first {
            $0.recordTable == .toDos && $0.recordID == recordID
        }
    }

    @discardableResult
    static func recordToDoConflict(
        localToDo: ToDo,
        syncedRecord: SupabaseSyncedToDoConflictRecord,
        userID: UUID,
        in context: ModelContext
    ) -> Bool {
        guard let recordID = localToDo.cloudID else { return false }
        if unresolvedConflict(recordID: recordID, userID: userID, in: context) != nil {
            return false
        }

        let conflict = SyncConflict(
            userID: userID,
            recordID: recordID,
            severity: .warning,
            title: "Sync Needs Review",
            message: "This ToDo changed on another device while this device had edits that were not synced yet.",
            localSummary: summary(task: localToDo.task, dueDate: localToDo.dueDate, isDone: localToDo.isDone),
            syncedSummary: summary(task: syncedRecord.task, dueDate: syncedRecord.dueDate, isDone: syncedRecord.isDone),
            localUpdatedAt: localToDo.syncUpdatedAt,
            syncedUpdatedAt: syncedRecord.updatedAt,
            syncedTask: syncedRecord.task,
            syncedNotes: syncedRecord.notes,
            syncedIsDone: syncedRecord.isDone,
            syncedLifecycleState: syncedRecord.lifecycleState,
            syncedReminderIntent: syncedRecord.reminderIntent,
            syncedDueDate: syncedRecord.dueDate,
            syncedRecurrenceUnit: syncedRecord.recurrenceUnit,
            syncedRecurrenceInterval: syncedRecord.recurrenceInterval,
            syncedRecurrenceMode: syncedRecord.recurrenceMode,
            syncedRecurrenceCount: syncedRecord.recurrenceCount,
            syncedRecurrenceAnchorDate: syncedRecord.recurrenceAnchorDate,
            syncedRecurrenceEndDate: syncedRecord.recurrenceEndDate
        )
        context.insert(conflict)
        return true
    }

    static func resolve(
        _ conflict: SyncConflict,
        resolution: SyncConflictResolution,
        toDos: [ToDo],
        in context: ModelContext
    ) throws {
        guard let recordID = conflict.recordID,
              let toDo = toDos.first(where: { $0.cloudID == recordID })
        else {
            conflict.resolvedAt = .now
            try context.save()
            return
        }

        switch resolution {
        case .keepDeviceVersion:
            toDo.markUpdated()
            conflict.resolvedAt = .now
        case .useSyncedVersion:
            applySyncedVersion(from: conflict, to: toDo)
            conflict.resolvedAt = .now
        }

        try context.save()
        SyncCoordinator.shared.scheduleLocalSync()
    }

    private static func applySyncedVersion(from conflict: SyncConflict, to toDo: ToDo) {
        toDo.task = conflict.syncedTask ?? toDo.task
        toDo.notes = conflict.syncedNotes ?? toDo.notes
        toDo.dueDate = conflict.syncedDueDate
        toDo.reminderIntent = conflict.syncedReminderIntent
        toDo.recurrenceUnit = conflict.syncedRecurrenceUnitRaw.flatMap(ToDoRecurrenceUnit.init(rawValue:))
        toDo.recurrenceInterval = conflict.syncedRecurrenceIntervalValue
        toDo.recurrenceMode = conflict.syncedRecurrenceModeRaw.flatMap(ToDoRecurrenceMode.init(rawValue:))
        toDo.recurrenceCount = conflict.syncedRecurrenceCountValue
        toDo.recurrenceAnchorDate = conflict.syncedRecurrenceAnchorDate
        toDo.recurrenceEndDate = conflict.syncedRecurrenceEndDate
        toDo.transition(to: conflict.syncedLifecycleState)
        toDo.updatedAt = conflict.syncedUpdatedAt
        toDo.lastSyncedUpdatedAt = conflict.syncedUpdatedAt
    }

    private static func summary(task: String, dueDate: Date?, isDone: Bool) -> String {
        var parts = [task.isEmpty ? "Untitled ToDo" : task]
        if isDone {
            parts.append("Done")
        }
        if let dueDate {
            parts.append("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }
}

struct SupabaseSyncedToDoConflictRecord {
    let task: String
    let notes: String
    let isDone: Bool
    let updatedAt: Date
    let lifecycleState: ToDoState
    let reminderIntent: ToDoReminderIntent
    let dueDate: Date?
    let recurrenceUnit: ToDoRecurrenceUnit?
    let recurrenceInterval: Int?
    let recurrenceMode: ToDoRecurrenceMode?
    let recurrenceCount: Int?
    let recurrenceAnchorDate: Date?
    let recurrenceEndDate: Date?
}
