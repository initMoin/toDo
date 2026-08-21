import Foundation
import SwiftData

enum ToDoSyncBackendError: Error {
    case accountCacheUnavailable
}

@MainActor
protocol ToDoSyncBackend: AnyObject {
    var syncMode: SyncMode { get }
    func configure(modelContainer: ModelContainer)
    func activate(userID: UUID?) async -> Bool
    func deactivate()
    func scheduleLocalSync()
    @discardableResult func flushLocalSync(userID: UUID?) async -> Bool
    func purgeLocalAccountCache(userID: UUID) throws
    func refreshFromRemote(userID: UUID?) async
}

extension ToDoSyncBackend {
    @discardableResult func flushLocalSync(userID: UUID?) async -> Bool { true }
    func purgeLocalAccountCache(userID: UUID) throws {}
    func refreshFromRemote(userID: UUID?) async {}
}
