import Foundation
import SwiftData

enum SyncDeletionMirroring {
    static func deleteDeviceOnlyCounterpartIfNeeded(
        for syncedToDo: ToDo,
        in context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) {
        SyncTombstoneStore.recordDelete(
            table: .toDos,
            recordID: syncedToDo.cloudID,
            userID: syncedToDo.ownerUserID,
            userDefaults: userDefaults
        )

        guard userDefaults.object(forKey: AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly) as? Bool ?? true else {
            return
        }
        guard syncedToDo.ownerUserID != nil else { return }

        let syncedID = syncedToDo.id

        do {
            let toDos = try context.fetch(FetchDescriptor<ToDo>())
            let counterparts = toDos.filter {
                guard $0.id != syncedID, $0.ownerUserID == nil else { return false }
                if let syncedCloudID = syncedToDo.cloudID, let localCloudID = $0.cloudID {
                    return localCloudID == syncedCloudID
                }
                return abs($0.createdAt.timeIntervalSince(syncedToDo.createdAt)) < 0.001
            }

            for counterpart in counterparts {
                context.delete(counterpart)
            }
        } catch {
            AppLog.error("Failed to mirror ToDo Sync delete locally: \(error)", logger: AppLog.sync)
        }
    }
}
