import Foundation
import SwiftData

@MainActor
final class CloudKitSyncBackend: ToDoSyncBackend {
    let syncMode: SyncMode = .iCloud

    func configure(modelContainer: ModelContainer) {}

    func activate(userID: UUID?) async -> Bool {
        // SwiftData + CloudKit mirroring is configured when the model container is created.
        // This backend exists so the app can treat iCloud as an explicit sync mode.
        true
    }

    func deactivate() {}

    func scheduleLocalSync() {}
}
