import Foundation
import SwiftData

struct SyncMigrationPlan: Equatable {
    let direction: SyncMigrationDirection
    let requiresAuthenticatedSupabaseAccount: Bool
    let requiresRelaunchToApply: Bool
    let summary: String
}

private struct PendingStoreMigration: Codable {
    let sourceModeRawValue: String
    let destinationModeRawValue: String
    let userID: UUID?
    let shouldTransferData: Bool?

    var sourceMode: SyncMode? {
        SyncMode(rawValue: sourceModeRawValue)
    }

    var destinationMode: SyncMode? {
        SyncMode(rawValue: destinationModeRawValue)
    }
}

@MainActor
final class MigrationService {
    static let shared = MigrationService()

    private var modelContainer: ModelContainer?

    private init() {}

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func plan(from sourceMode: SyncMode, to destinationMode: SyncMode) -> SyncMigrationPlan? {
        guard sourceMode != destinationMode,
              let direction = SyncMigrationDirection.allCases.first(where: {
                  $0.sourceMode == sourceMode && $0.destinationMode == destinationMode
              })
        else {
            return nil
        }

        return SyncMigrationPlan(
            direction: direction,
            requiresAuthenticatedSupabaseAccount: destinationMode == .syncEverywhere,
            requiresRelaunchToApply: destinationMode == .iCloud || sourceMode == .iCloud,
            summary: summary(for: direction)
        )
    }

    func stagePendingStoreMigrationIfNeeded(
        from sourceMode: SyncMode,
        to destinationMode: SyncMode,
        userID: UUID?,
        shouldTransferData: Bool,
        userDefaults: UserDefaults = .standard
    ) {
        guard sourceMode != destinationMode else {
            clearPendingStoreMigration(userDefaults: userDefaults)
            return
        }

        guard let plan = plan(from: sourceMode, to: destinationMode),
              plan.requiresRelaunchToApply
        else {
            clearPendingStoreMigration(userDefaults: userDefaults)
            return
        }

        let payload = PendingStoreMigration(
            sourceModeRawValue: sourceMode.rawValue,
            destinationModeRawValue: destinationMode.rawValue,
            userID: userID,
            shouldTransferData: shouldTransferData
        )

        do {
            let data = try JSONEncoder().encode(payload)
            userDefaults.set(data, forKey: AppPreferences.Keys.pendingStoreMigration)
        } catch {
            print("Failed to stage pending store migration: \(error)")
        }
    }

    func runPendingStoreMigrationIfNeeded(
        into destinationContainer: ModelContainer,
        activeMode: SyncMode,
        userDefaults: UserDefaults = .standard
    ) {
        guard let data = userDefaults.data(forKey: AppPreferences.Keys.pendingStoreMigration) else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(PendingStoreMigration.self, from: data)
            guard let sourceMode = payload.sourceMode,
                  let destinationMode = payload.destinationMode
            else {
                clearPendingStoreMigration(userDefaults: userDefaults)
                return
            }

            guard destinationMode == activeMode else { return }
            guard payload.shouldTransferData != false else {
                clearPendingStoreMigration(userDefaults: userDefaults)
                return
            }

            let sourceURL = Self.storeURL(for: sourceMode)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                clearPendingStoreMigration(userDefaults: userDefaults)
                return
            }

            let sourceConfiguration = ModelConfiguration(
                "ToDo",
                url: sourceURL,
                cloudKitDatabase: CloudKitConfig.database(for: sourceMode)
            )
            let sourceContainer = try ModelContainer(
                for: ToDo.self,
                Tag.self,
                NanoDo.self,
                SyncConflict.self,
                configurations: sourceConfiguration
            )

            try transferSnapshot(
                from: sourceMode,
                to: destinationMode,
                userID: payload.userID,
                sourceContainer: sourceContainer,
                destinationContainer: destinationContainer
            )

            clearPendingStoreMigration(userDefaults: userDefaults)
        } catch {
            print("Pending store migration failed: \(error)")
        }
    }

    private func summary(for direction: SyncMigrationDirection) -> String {
        switch direction {
        case .deviceOnlyToICloud:
            return "Move local ToDos into iCloud sync for Apple devices."
        case .deviceOnlyToSyncEverywhere:
            return "Adopt local ToDos into ToDo Sync for cross-platform access."
        case .iCloudToSyncEverywhere:
            return "Copy your iCloud-backed ToDos into ToDo Sync for Android and web access."
        case .iCloudToDeviceOnly:
            return "Stop syncing with iCloud and keep your ToDos on this device."
        case .syncEverywhereToDeviceOnly:
            return "Copy your latest synced ToDos into device-only storage and step away from account sync."
        case .syncEverywhereToICloud:
            return "Move your ToDo Sync data into iCloud sync for Apple-only use."
        }
    }

    func executeIfNeeded(
        from sourceMode: SyncMode,
        to destinationMode: SyncMode,
        userID: UUID?,
        shouldTransferData: Bool = true
    ) throws {
        guard let plan = plan(from: sourceMode, to: destinationMode),
              let modelContainer
        else {
            return
        }

        guard shouldTransferData else { return }

        switch plan.direction {
        case .syncEverywhereToDeviceOnly:
            guard let userID else { return }
            try materializeDeviceOnlySnapshot(from: userID, in: modelContainer)
        default:
            return
        }
    }

    private func clearPendingStoreMigration(userDefaults: UserDefaults) {
        userDefaults.removeObject(forKey: AppPreferences.Keys.pendingStoreMigration)
    }

    private func transferSnapshot(
        from sourceMode: SyncMode,
        to destinationMode: SyncMode,
        userID: UUID?,
        sourceContainer: ModelContainer,
        destinationContainer: ModelContainer
    ) throws {
        let sourceContext = ModelContext(sourceContainer)
        let destinationContext = ModelContext(destinationContainer)

        let sourceTags = try fetchScopedTags(in: sourceContext, mode: sourceMode, userID: userID)
        let sourceToDos = try fetchScopedToDos(in: sourceContext, mode: sourceMode, userID: userID)
        let sourceNanoDos = try fetchScopedNanoDos(in: sourceContext, mode: sourceMode, userID: userID)

        guard sourceTags.isEmpty == false || sourceToDos.isEmpty == false || sourceNanoDos.isEmpty == false else {
            return
        }

        try clearScopedData(in: destinationContext, mode: destinationMode, userID: userID)

        let destinationOwnerUserID = destinationMode == .syncEverywhere ? userID : nil
        var clonedTagsByID: [PersistentIdentifier: Tag] = [:]

        for sourceTag in sourceTags {
            let clonedTag = Tag(
                name: sourceTag.name,
                createdAt: sourceTag.createdAt,
                updatedAt: sourceTag.updatedAt,
                cloudID: sourceTag.cloudID,
                ownerUserID: destinationOwnerUserID
            )
            destinationContext.insert(clonedTag)
            clonedTagsByID[sourceTag.id] = clonedTag
        }

        var clonedToDosByID: [PersistentIdentifier: ToDo] = [:]
        for sourceToDo in sourceToDos {
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
                cloudID: sourceToDo.cloudID,
                ownerUserID: destinationOwnerUserID
            )
            destinationContext.insert(clonedToDo)
            clonedToDo.setSelectedTags(
                sourceToDo.effectiveTags.compactMap { clonedTagsByID[$0.id] }
            )
            clonedToDo.updatedAt = sourceToDo.updatedAt
            clonedToDosByID[sourceToDo.id] = clonedToDo
        }

        var clonedNanoDosByToDoID: [PersistentIdentifier: [NanoDo]] = [:]
        for sourceNanoDo in sourceNanoDos {
            let clonedParent = sourceNanoDo.toDo.flatMap { clonedToDosByID[$0.id] }
            let clonedTag = sourceNanoDo.tag.flatMap { clonedTagsByID[$0.id] }
            let clonedNanoDo = NanoDo(
                task: sourceNanoDo.task,
                createdAt: sourceNanoDo.createdAt,
                updatedAt: sourceNanoDo.updatedAt,
                dueDate: sourceNanoDo.dueDate,
                isDone: sourceNanoDo.isDone,
                toDo: clonedParent,
                tag: clonedTag ?? clonedParent?.effectiveTags.first,
                cloudID: sourceNanoDo.cloudID,
                ownerUserID: destinationOwnerUserID
            )
            destinationContext.insert(clonedNanoDo)

            if let sourceParentID = sourceNanoDo.toDo?.id {
                clonedNanoDosByToDoID[sourceParentID, default: []].append(clonedNanoDo)
            }
        }

        for (sourceToDoID, clonedToDo) in clonedToDosByID {
            clonedToDo.nanoDos = clonedNanoDosByToDoID[sourceToDoID, default: []]
        }

        try destinationContext.save()
    }

    private func materializeDeviceOnlySnapshot(from userID: UUID, in modelContainer: ModelContainer) throws {
        let context = ModelContext(modelContainer)
        let ownedTags = try context.fetch(FetchDescriptor<Tag>()).filter { $0.ownerUserID == userID }
        let ownedToDos = try context.fetch(FetchDescriptor<ToDo>()).filter { $0.ownerUserID == userID }
        let ownedNanoDos = try context.fetch(FetchDescriptor<NanoDo>()).filter { $0.ownerUserID == userID }

        guard ownedTags.isEmpty == false || ownedToDos.isEmpty == false || ownedNanoDos.isEmpty == false else {
            return
        }

        var clonedTagsByID: [PersistentIdentifier: Tag] = [:]
        for sourceTag in ownedTags {
            let clonedTag = Tag(
                name: sourceTag.name,
                createdAt: sourceTag.createdAt,
                updatedAt: sourceTag.updatedAt,
                cloudID: sourceTag.cloudID,
                ownerUserID: nil
            )
            context.insert(clonedTag)
            clonedTagsByID[sourceTag.id] = clonedTag
        }

        var clonedToDosByID: [PersistentIdentifier: ToDo] = [:]
        for sourceToDo in ownedToDos {
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
                cloudID: sourceToDo.cloudID,
                ownerUserID: nil
            )
            context.insert(clonedToDo)
            clonedToDo.setSelectedTags(
                sourceToDo.effectiveTags.compactMap { clonedTagsByID[$0.id] }
            )
            clonedToDo.updatedAt = sourceToDo.updatedAt
            clonedToDosByID[sourceToDo.id] = clonedToDo
        }

        var clonedNanoDosByToDoID: [PersistentIdentifier: [NanoDo]] = [:]
        for sourceNanoDo in ownedNanoDos {
            let clonedParent = sourceNanoDo.toDo.flatMap { clonedToDosByID[$0.id] }
            let clonedTag = sourceNanoDo.tag.flatMap { clonedTagsByID[$0.id] }
            let clonedNanoDo = NanoDo(
                task: sourceNanoDo.task,
                createdAt: sourceNanoDo.createdAt,
                updatedAt: sourceNanoDo.updatedAt,
                dueDate: sourceNanoDo.dueDate,
                isDone: sourceNanoDo.isDone,
                toDo: clonedParent,
                tag: clonedTag ?? clonedParent?.effectiveTags.first,
                cloudID: sourceNanoDo.cloudID,
                ownerUserID: nil
            )
            context.insert(clonedNanoDo)

            if let sourceParentID = sourceNanoDo.toDo?.id {
                clonedNanoDosByToDoID[sourceParentID, default: []].append(clonedNanoDo)
            }
        }

        for (sourceToDoID, clonedToDo) in clonedToDosByID {
            clonedToDo.nanoDos = clonedNanoDosByToDoID[sourceToDoID, default: []]
        }

        try context.save()
    }

    private func fetchScopedTags(in context: ModelContext, mode: SyncMode, userID: UUID?) throws -> [Tag] {
        let allTags = try context.fetch(FetchDescriptor<Tag>())
        return allTags.filter { tag in
            switch mode {
            case .syncEverywhere:
                return tag.ownerUserID == userID
            case .deviceOnly, .iCloud:
                return tag.ownerUserID == nil
            }
        }
    }

    private func fetchScopedToDos(in context: ModelContext, mode: SyncMode, userID: UUID?) throws -> [ToDo] {
        let allToDos = try context.fetch(FetchDescriptor<ToDo>())
        return allToDos.filter { toDo in
            switch mode {
            case .syncEverywhere:
                return toDo.ownerUserID == userID
            case .deviceOnly, .iCloud:
                return toDo.ownerUserID == nil
            }
        }
    }

    private func fetchScopedNanoDos(in context: ModelContext, mode: SyncMode, userID: UUID?) throws -> [NanoDo] {
        let allNanoDos = try context.fetch(FetchDescriptor<NanoDo>())
        return allNanoDos.filter { nanoDo in
            switch mode {
            case .syncEverywhere:
                return nanoDo.ownerUserID == userID
            case .deviceOnly, .iCloud:
                return nanoDo.ownerUserID == nil
            }
        }
    }

    private func clearScopedData(in context: ModelContext, mode: SyncMode, userID: UUID?) throws {
        let existingNanoDos = try fetchScopedNanoDos(in: context, mode: mode, userID: userID)
        let existingToDos = try fetchScopedToDos(in: context, mode: mode, userID: userID)
        let existingTags = try fetchScopedTags(in: context, mode: mode, userID: userID)

        for nanoDo in existingNanoDos {
            context.delete(nanoDo)
        }
        for toDo in existingToDos {
            context.delete(toDo)
        }
        for tag in existingTags {
            context.delete(tag)
        }
    }

    private static func storeURL(for syncMode: SyncMode) -> URL {
        let fileManager = FileManager.default
        let applicationSupport: URL

        do {
            applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            applicationSupport = URL.applicationSupportDirectory
        }

        let fileName: String
        switch syncMode {
        case .deviceOnly, .syncEverywhere:
            fileName = "default.store"
        case .iCloud:
            fileName = "icloud.store"
        }

        return applicationSupport.appending(path: fileName)
    }
}
