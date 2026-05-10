import Foundation
import SwiftData

@MainActor
protocol ToDoSyncBackend: AnyObject {
    var syncMode: SyncMode { get }
    func configure(modelContainer: ModelContainer)
    func activate(userID: UUID?) async -> Bool
    func deactivate()
    func scheduleLocalSync()
    func flushLocalSync(userID: UUID?) async
    func refreshFromRemote(userID: UUID?) async
}

extension ToDoSyncBackend {
    func flushLocalSync(userID: UUID?) async {}
    func refreshFromRemote(userID: UUID?) async {}
}
