import Foundation
import Testing
@testable import ToDo

@Suite("Watch bridge codec")
@MainActor
struct WatchBridgeCodecTests {
   @Test func snapshotEnvelopeRoundTripsWithTrashedItems() throws {
      let activeItem = WatchToDoItem(
         id: "local-1",
         cloudID: UUID(),
         task: "Review watch handoff",
         isDone: false,
         lifecycleState: .active,
         trashedAt: nil,
         dueDate: Date(timeIntervalSinceReferenceDate: 900),
         isTimeSensitive: true,
         createdAt: Date(timeIntervalSinceReferenceDate: 800),
         updatedAt: Date(timeIntervalSinceReferenceDate: 1_000)
      )
      
      let trashedItem = WatchToDoItem(
         id: "local-2",
         cloudID: UUID(),
         task: "Old task in trash",
         isDone: false,
         lifecycleState: .trashed,
         trashedAt: Date(timeIntervalSinceReferenceDate: 1_050),
         dueDate: nil,
         isTimeSensitive: false,
         createdAt: Date(timeIntervalSinceReferenceDate: 800),
         updatedAt: Date(timeIntervalSinceReferenceDate: 1_100)
      )

      let snapshot = WatchToDoSnapshot(
         generatedAt: Date(timeIntervalSinceReferenceDate: 1_100),
         syncMode: .syncEverywhere,
         authState: WatchAuthState(
            isAuthenticated: true,
            userID: UUID(),
            provider: "Apple",
            email: "watch@example.com",
            source: .iPhone,
            issuedAt: Date(timeIntervalSinceReferenceDate: 1_090)
         ),
         items: [activeItem, trashedItem]
      )

      let envelope = try WatchBridgeCodec.envelope(kind: .snapshot, payload: snapshot)
      let decodedSnapshot = try WatchBridgeCodec.decodePayload(WatchToDoSnapshot.self, from: envelope)
      let decoded = try #require(decodedSnapshot)

      #expect(WatchBridgeCodec.decodeKind(from: envelope) == .snapshot)
      #expect(decoded == snapshot)
      #expect(decoded.items.count == 2)
      
      let decodedTrashed = try #require(decoded.items.first(where: { $0.id == "local-2" }))
      #expect(decodedTrashed.lifecycleState == .trashed)
      #expect(decodedTrashed.trashedAt != nil)
   }

   @Test func authStateEnvelopeCarriesProviderAndSource() throws {
      let userID = UUID()
      let authState = WatchAuthState(
         isAuthenticated: true,
         userID: userID,
         provider: "Apple",
         email: "person@example.com",
         source: .iPhone,
         issuedAt: Date(timeIntervalSinceReferenceDate: 1_400)
      )

      let envelope = try WatchBridgeCodec.envelope(kind: .authState, payload: authState)
      let decodedAuthState = try WatchBridgeCodec.decodePayload(WatchAuthState.self, from: envelope)
      let decoded = try #require(decodedAuthState)

      #expect(WatchBridgeCodec.decodeKind(from: envelope) == .authState)
      #expect(decoded == authState)
      #expect(decoded.userID == userID)
      #expect(decoded.provider == "Apple")
      #expect(decoded.source == .iPhone)
   }

   @Test func actionEnvelopeKeepsLocalAndCloudIdentifiersDistinct() throws {
      let cloudID = UUID()
      let action = WatchToDoAction(
         type: .complete,
         localIdentifier: "swiftdata-local-id",
         cloudID: cloudID,
         occurredAt: Date(timeIntervalSinceReferenceDate: 1_200)
      )

      let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
      let decodedAction = try WatchBridgeCodec.decodePayload(WatchToDoAction.self, from: envelope)
      let decoded = try #require(decodedAction)

      #expect(WatchBridgeCodec.decodeKind(from: envelope) == .action)
      #expect(decoded.localIdentifier == "swiftdata-local-id")
      #expect(decoded.cloudID == cloudID)
   }
}

