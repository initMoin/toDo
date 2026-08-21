import Foundation
import SwiftData

@MainActor
final class CloudKitSyncBackend: ToDoSyncBackend {
    let syncMode: SyncMode = .iCloud

    func configure(modelContainer: ModelContainer) {}

    func activate(userID: UUID?) async -> Bool {
        true
    }

    func deactivate() {}

    func scheduleLocalSync() {}
}
