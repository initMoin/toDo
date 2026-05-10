import Foundation
import Testing
@testable import ToDo

@Suite("Sync tombstone store")
@MainActor
struct SyncTombstoneStoreTests {
    @Test func recordDeletePersistsPendingTombstoneForUser() throws {
        let defaults = try #require(UserDefaults(suiteName: "SyncTombstoneStoreTests.record"))
        defer { defaults.removePersistentDomain(forName: "SyncTombstoneStoreTests.record") }

        let userID = UUID()
        let recordID = UUID()

        SyncTombstoneStore.recordDelete(
            table: .toDos,
            recordID: recordID,
            userID: userID,
            deletedAt: Date(timeIntervalSinceReferenceDate: 30),
            userDefaults: defaults
        )

        let pending = SyncTombstoneStore.pendingTombstones(for: userID, userDefaults: defaults)
        #expect(pending == [
            SyncTombstone(
                userID: userID,
                recordTable: .toDos,
                recordID: recordID,
                deletedAt: Date(timeIntervalSinceReferenceDate: 30)
            )
        ])
    }

    @Test func removeSyncedTombstonesLeavesOtherUsersPending() throws {
        let defaults = try #require(UserDefaults(suiteName: "SyncTombstoneStoreTests.remove"))
        defer { defaults.removePersistentDomain(forName: "SyncTombstoneStoreTests.remove") }

        let synced = SyncTombstone(
            userID: UUID(),
            recordTable: .toDos,
            recordID: UUID(),
            deletedAt: Date(timeIntervalSinceReferenceDate: 40)
        )
        let other = SyncTombstone(
            userID: UUID(),
            recordTable: .tags,
            recordID: UUID(),
            deletedAt: Date(timeIntervalSinceReferenceDate: 50)
        )

        SyncTombstoneStore.recordDelete(
            table: synced.recordTable,
            recordID: synced.recordID,
            userID: synced.userID,
            deletedAt: synced.deletedAt,
            userDefaults: defaults
        )
        SyncTombstoneStore.recordDelete(
            table: other.recordTable,
            recordID: other.recordID,
            userID: other.userID,
            deletedAt: other.deletedAt,
            userDefaults: defaults
        )

        SyncTombstoneStore.removeSyncedTombstones([synced], userDefaults: defaults)

        #expect(SyncTombstoneStore.pendingTombstones(userDefaults: defaults) == [other])
    }

    @Test func recordDeleteReplacesExistingPendingTombstoneForSameRecord() throws {
        let defaults = try #require(UserDefaults(suiteName: "SyncTombstoneStoreTests.replace"))
        defer { defaults.removePersistentDomain(forName: "SyncTombstoneStoreTests.replace") }

        let userID = UUID()
        let recordID = UUID()
        let firstDeletedAt = Date(timeIntervalSinceReferenceDate: 60)
        let secondDeletedAt = Date(timeIntervalSinceReferenceDate: 90)

        SyncTombstoneStore.recordDelete(
            table: .toDos,
            recordID: recordID,
            userID: userID,
            deletedAt: firstDeletedAt,
            userDefaults: defaults
        )
        SyncTombstoneStore.recordDelete(
            table: .toDos,
            recordID: recordID,
            userID: userID,
            deletedAt: secondDeletedAt,
            userDefaults: defaults
        )

        let pending = SyncTombstoneStore.pendingTombstones(for: userID, userDefaults: defaults)
        #expect(pending == [
            SyncTombstone(
                userID: userID,
                recordTable: .toDos,
                recordID: recordID,
                deletedAt: secondDeletedAt
            )
        ])
    }
}
