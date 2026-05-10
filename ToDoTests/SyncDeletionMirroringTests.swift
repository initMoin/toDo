import Foundation
import SwiftData
import Testing
@testable import ToDo

@Suite("Sync deletion mirroring")
@MainActor
struct SyncDeletionMirroringTests {
    @Test func syncedDeleteRemovesMatchingDeviceOnlyCounterpartByDefault() throws {
        let context = try makeContext()
        let createdAt = Date(timeIntervalSinceReferenceDate: 10)
        let localToDo = ToDo(task: "Budget", createdAt: createdAt)
        let syncedToDo = ToDo(
            task: "Budget",
            createdAt: createdAt,
            cloudID: UUID(),
            ownerUserID: UUID()
        )
        context.insert(localToDo)
        context.insert(syncedToDo)

        SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: syncedToDo, in: context)
        context.delete(syncedToDo)
        try context.save()

        let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
        #expect(remainingToDos.isEmpty)
    }

    @Test func syncedDeleteKeepsDeviceOnlyCounterpartWhenPreferenceIsOff() throws {
        let context = try makeContext()
        let defaults = try #require(UserDefaults(suiteName: "SyncDeletionMirroringTests"))
        defaults.set(false, forKey: AppPreferences.Keys.mirrorSyncDeletesToDeviceOnly)
        defer { defaults.removePersistentDomain(forName: "SyncDeletionMirroringTests") }

        let createdAt = Date(timeIntervalSinceReferenceDate: 20)
        let localToDo = ToDo(task: "Budget", createdAt: createdAt)
        let syncedToDo = ToDo(
            task: "Budget",
            createdAt: createdAt,
            cloudID: UUID(),
            ownerUserID: UUID()
        )
        context.insert(localToDo)
        context.insert(syncedToDo)

        SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
            for: syncedToDo,
            in: context,
            userDefaults: defaults
        )
        context.delete(syncedToDo)
        try context.save()

        let remainingToDos = try context.fetch(FetchDescriptor<ToDo>())
        #expect(remainingToDos.map(\.task) == ["Budget"])
        #expect(remainingToDos.first?.ownerUserID == nil)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: ToDo.self,
            Tag.self,
            NanoDo.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
