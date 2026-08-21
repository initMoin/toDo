import Foundation
import SwiftData

@MainActor
final class SupabaseSyncBackend: ToDoSyncBackend {
    let syncMode: SyncMode = .syncEverywhere

    private let syncService: SupabaseSyncService

    init(syncService: SupabaseSyncService = .shared) {
        self.syncService = syncService
    }

    func configure(modelContainer: ModelContainer) {
        syncService.configure(modelContainer: modelContainer)
    }

    func activate(userID: UUID?) async -> Bool {
        guard let userID else {
            syncService.deactivate()
            return false
        }

        return await syncService.activate(for: userID)
    }

    func deactivate() {
        syncService.deactivate()
    }

    func scheduleLocalSync() {
        syncService.scheduleLocalSync()
    }

    @discardableResult
    func flushLocalSync(userID: UUID?) async -> Bool {
        guard let userID else { return false }
        return await syncService.flushLocalSync(for: userID)
    }

    func purgeLocalAccountCache(userID: UUID) throws {
        try syncService.purgeLocalAccountCache(for: userID)
    }

    func refreshFromRemote(userID: UUID?) async {
        guard let userID else { return }
        await syncService.refreshFromRemote(for: userID)
    }
}
