import Foundation
import SwiftData

@MainActor
enum SyncDeletionMirroring {
    static func deleteDeviceOnlyCounterpartIfNeeded(
        for syncedToDo: ToDo,
        in context: ModelContext,
        actingUserID: UUID? = nil,
        recordsSyncTombstone: Bool = true,
        userDefaults: UserDefaults = .standard
    ) {
        if recordsSyncTombstone {
            SyncTombstoneStore.recordDelete(
                table: .toDos,
                recordID: syncedToDo.cloudID,
                userID: actingUserID ?? syncedToDo.ownerUserID,
                collabID: syncedToDo.collabID,
                userDefaults: userDefaults
            )
        }

        guard userDefaults.object(forKey: AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly) as? Bool ?? true else {
            return
        }
        guard syncedToDo.ownerUserID != nil, syncedToDo.collabID == nil else { return }

        let syncedID = syncedToDo.id

        do {
            let descriptor = FetchDescriptor<ToDo>(
                predicate: #Predicate<ToDo> { toDo in
                    toDo.ownerUserID == nil
                }
            )
            let toDos = try context.fetch(descriptor)
            let counterparts = toDos.filter {
                guard $0.id != syncedID else { return false }
                if let syncedCloudID = syncedToDo.cloudID, let localCloudID = $0.cloudID {
                    return localCloudID == syncedCloudID
                }
                return abs($0.createdAt.timeIntervalSince(syncedToDo.createdAt)) < 0.001
            }

            for counterpart in counterparts {
                context.delete(counterpart)
            }
        } catch {
            AppLog.error("Failed to mirror toDō Sync delete locally: \(error)", logger: AppLog.sync)
        }
    }
}

@MainActor
enum ToDoLocalAccountDeletionService {
    /// Removes every local record after the server confirms account deletion.
    /// No sync is scheduled afterward because there is no account left to sync.
    static func clearAll(
        userID: UUID,
        in context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws {
        let toDos = try context.fetch(FetchDescriptor<ToDo>())
        do {
            try CalendarIntegrationService.shared.removeCalendarEvents(for: toDos)
        } catch {
            AppLog.error("Account deletion could not remove every Calendar mirror: \(error)", logger: AppLog.calendar)
        }

        #if os(iOS)
        for toDo in toDos {
            LiveActivityService.shared.endActivity(for: toDo)
        }
        #endif

        let nanoDos = try context.fetch(FetchDescriptor<NanoDo>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let conflicts = try context.fetch(FetchDescriptor<SyncConflict>())
        nanoDos.forEach(context.delete)
        toDos.forEach(context.delete)
        tags.forEach(context.delete)
        conflicts.forEach(context.delete)
        try context.save()

        SyncTombstoneStore.removeAll(userDefaults: userDefaults)
        ToDoProfileImageStore.clear(for: userID)
        userDefaults.removeObject(forKey: "todo.mac.menuSnapshot")

        NotificationManager.shared.scheduleRefresh()
        WidgetSnapshotService.shared.writeSnapshot(from: context)
    }
}

enum ToDoDataResetSharedListChoice: Sendable {
    case keep
    case leave
}

struct ToDoDataResetReport: Equatable, Sendable {
    let deletedPersonalToDoCount: Int
    let deletedOrphanNanoDoCount: Int
    let leftSharedListCount: Int
    let preservedOwnedSharedListCount: Int
}

@MainActor
enum ToDoDataResetService {
    static func reset(
        toDos: [ToDo],
        accountUserID: UUID?,
        sharedListChoice: ToDoDataResetSharedListChoice,
        collaborationService: ToDoCollaborationService,
        in context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async throws -> ToDoDataResetReport {
        let personalToDos = toDos.filter {
            shouldDeletePersonalToDo(
                ownerUserID: $0.ownerUserID,
                collabID: $0.collabID,
                accountUserID: accountUserID
            )
        }

        let leaveResult: ToDoCollaborationLeaveResult
        switch sharedListChoice {
        case .keep:
            leaveResult = ToDoCollaborationLeaveResult(
                leftCollabIDs: [],
                preservedOwnedCollabCount: collaborationService.collabs.count {
                    $0.ownerUserID == accountUserID
                }
            )
        case .leave:
            leaveResult = try await collaborationService.leaveSharedCollabs()
        }

        let allNanoDos = try context.fetch(FetchDescriptor<NanoDo>())
        let personalToDoIDs = Set(personalToDos.map(\.id))
        let orphanNanoDos = allNanoDos.filter { nanoDo in
            guard nanoDo.toDo == nil else { return false }
            return accountUserID == nil
                ? nanoDo.ownerUserID == nil
                : nanoDo.ownerUserID == nil || nanoDo.ownerUserID == accountUserID
        }
        let orphanNanoDoIDs = Set(orphanNanoDos.map(\.id))
        let nanoDosToTombstone = allNanoDos.filter { nanoDo in
            if let parentID = nanoDo.toDo?.id, personalToDoIDs.contains(parentID) {
                return true
            }
            return orphanNanoDoIDs.contains(nanoDo.id)
        }
        let deletedAt = Date.now
        let tombstones: [SyncTombstone]
        if let accountUserID {
            tombstones = personalToDos.compactMap { toDo -> SyncTombstone? in
                guard let cloudID = toDo.cloudID else { return nil }
                return SyncTombstone(
                    userID: accountUserID,
                    recordTable: .toDos,
                    recordID: cloudID,
                    deletedAt: deletedAt
                )
            } + nanoDosToTombstone.compactMap { nanoDo -> SyncTombstone? in
                guard let cloudID = nanoDo.cloudID else { return nil }
                return SyncTombstone(
                    userID: accountUserID,
                    recordTable: .nanoDos,
                    recordID: cloudID,
                    deletedAt: deletedAt
                )
            }
        } else {
            tombstones = []
        }

        do {
            try CalendarIntegrationService.shared.removeCalendarEvents(for: personalToDos)
        } catch {
            AppLog.error("Reset could not remove every Calendar mirror: \(error)", logger: AppLog.calendar)
        }

        for toDo in personalToDos {
            #if os(iOS)
            LiveActivityService.shared.endActivity(for: toDo)
            #endif
            context.delete(toDo)
        }
        for nanoDo in orphanNanoDos {
            context.delete(nanoDo)
        }

        if !leaveResult.leftCollabIDs.isEmpty {
            for toDo in toDos where toDo.collabID.map(leaveResult.leftCollabIDs.contains) == true {
                context.delete(toDo)
            }
        }

        try context.save()
        SyncTombstoneStore.recordDeletes(tombstones, userDefaults: userDefaults)

        NotificationManager.shared.scheduleRefresh()
        SyncCoordinator.shared.scheduleLocalSync()

        return ToDoDataResetReport(
            deletedPersonalToDoCount: personalToDos.count,
            deletedOrphanNanoDoCount: orphanNanoDos.count,
            leftSharedListCount: leaveResult.leftCollabIDs.count,
            preservedOwnedSharedListCount: leaveResult.preservedOwnedCollabCount
        )
    }

    static func shouldDeletePersonalToDo(
        ownerUserID: UUID?,
        collabID: UUID?,
        accountUserID: UUID?
    ) -> Bool {
        guard collabID == nil else { return false }
        guard let accountUserID else { return ownerUserID == nil }
        return ownerUserID == nil || ownerUserID == accountUserID
    }
}
