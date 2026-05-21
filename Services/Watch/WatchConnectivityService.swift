import Combine
import Foundation
import SwiftData

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity

private struct WatchSessionSnapshot: Sendable {
   let isPaired: Bool
   let isWatchAppInstalled: Bool
   let isReachable: Bool
   let activationState: WCSessionActivationState
}

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
   static let shared = WatchConnectivityService()

   @Published private(set) var isSupported = WCSession.isSupported()
   @Published private(set) var isPaired = false
   @Published private(set) var isWatchAppInstalled = false
   @Published private(set) var isReachable = false
   @Published private(set) var activationState: WCSessionActivationState = .notActivated
   @Published private(set) var lastReceivedAction: WatchToDoAction?
   @Published private(set) var lastSentAt: Date?
   @Published private(set) var lastErrorMessage: String?

   private var modelContainer: ModelContainer?

   private var session: WCSession? {
      guard WCSession.isSupported() else { return nil }
      return .default
   }

   private override init() {
      super.init()
   }

   func configure(modelContainer: ModelContainer) {
      self.modelContainer = modelContainer

      guard let session else {
         isSupported = false
         return
      }

      session.delegate = self
      activationState = session.activationState

      if session.activationState == .notActivated {
         session.activate()
         return
      }

      applyState(Self.snapshot(from: session))
      refreshSnapshot()
   }

   func send(snapshot: WatchToDoSnapshot) {
      guard let session, canSendToWatch(session) else { return }

      do {
         let envelope = try WatchBridgeCodec.envelope(kind: .snapshot, payload: snapshot)

         try session.updateApplicationContext(envelope)
         lastSentAt = snapshot.generatedAt
         lastErrorMessage = nil
      } catch {
         lastErrorMessage = error.localizedDescription
      }
   }

   func send(receipt: WatchToDoActionReceipt) {
      guard let session, canSendToWatch(session) else { return }

      do {
         let envelope = try WatchBridgeCodec.envelope(kind: .actionReceipt, payload: receipt)

         if session.isReachable {
            session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
               Task { @MainActor in
                  self?.lastErrorMessage = error.localizedDescription
               }
            }
         } else {
            session.transferUserInfo(envelope)
         }

         lastSentAt = receipt.handledAt
         lastErrorMessage = nil
      } catch {
         lastErrorMessage = error.localizedDescription
      }
   }

   func send(authState: WatchAuthState) {
      guard let session, canSendToWatch(session) else { return }

      do {
         let envelope = try WatchBridgeCodec.envelope(kind: .authState, payload: authState)

         if session.isReachable {
            session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
               Task { @MainActor in
                  self?.lastErrorMessage = error.localizedDescription
               }
            }
         } else {
            session.transferUserInfo(envelope)
         }

         lastSentAt = authState.issuedAt
         lastErrorMessage = nil
      } catch {
         lastErrorMessage = error.localizedDescription
      }
   }

   private func handle(envelope: WatchEnvelopeParts) {
      guard let kind = WatchBridgeCodec.decodeKind(
         schemaVersion: envelope.schemaVersion,
         rawKind: envelope.rawKind
      ) else { return }

      do {
         switch kind {
         case .action:
            guard let action = try WatchBridgeCodec.decodePayload(
               WatchToDoAction.self,
               from: envelope.payload
            ) else { return }
            lastReceivedAction = action
            handle(action: action)
         case .snapshot, .actionReceipt, .authState:
            break
         }
         lastErrorMessage = nil
      } catch {
         lastErrorMessage = error.localizedDescription
      }
   }

   func refreshSnapshot() {
      guard let container = modelContainer,
            let session,
            canSendToWatch(session) else { return }

      let context = ModelContext(container)

      do {
         let allToDos = try context.fetch(FetchDescriptor<ToDo>())
         let syncMode = SyncCoordinator.shared.effectiveSyncMode
         let ownerUserID = syncMode == .syncEverywhere ? SupabaseAuthStore.shared.currentUserID : nil
         let visibleToDos = allToDos
            .filter { $0.ownerUserID == ownerUserID && !$0.isArchived }
            .sorted(by: watchSort)
            .prefix(20)
         let items = visibleToDos.map { toDo in
            WatchToDoItem(
               id: persistentIdentifierString(for: toDo),
               cloudID: toDo.cloudID,
               task: toDo.task,
               isDone: toDo.isDoneState,
               dueDate: toDo.dueDate,
               isTimeSensitive: toDo.reminderIntent == .timeSensitive,
               createdAt: toDo.createdAt,
               updatedAt: toDo.syncUpdatedAt
            )
         }

         send(snapshot: WatchToDoSnapshot(
            syncMode: WatchSyncMode(syncMode),
            authState: currentAuthState(),
            items: Array(items)
         ))
      } catch {
         lastErrorMessage = error.localizedDescription
      }
   }

   private func handle(action: WatchToDoAction) {
      let actionName = action.type.rawValue.capitalized

      switch action.type {
      case .requestRefresh:
         refreshSnapshot()
         send(authState: currentAuthState())
         send(receipt: WatchToDoActionReceipt(actionID: action.id, accepted: true))
      case .create:
         createToDo(from: action)
      case .complete, .reopen, .setDueDate, .snooze, .openOnPhone:
         apply(action: action)

         SyncCoordinator.shared.showTransientFeedback(
            title: "Watch Update",
            message: "Applied \(actionName) successfully",
            style: .success
         )
      }
   }

   private func createToDo(from action: WatchToDoAction) {
      guard let container = modelContainer else {
         send(receipt: WatchToDoActionReceipt(
            actionID: action.id,
            accepted: false,
            message: "iPhone data store is not ready."
         ))
         return
      }

      let task = action.task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      guard !task.isEmpty else {
         send(receipt: WatchToDoActionReceipt(
            actionID: action.id,
            accepted: false,
            message: "Add a task before saving."
         ))
         return
      }

      let context = ModelContext(container)
      let dueDate = action.dueDate
      let reminderIntent: ToDoReminderIntent = {
         guard dueDate != nil else { return .soft }
         return action.isTimeSensitive == true ? .timeSensitive : .due
      }()
      let syncMode = SyncCoordinator.shared.effectiveSyncMode
      let ownerUserID = syncMode == .syncEverywhere ? SupabaseAuthStore.shared.currentUserID : nil

      do {
         let toDo = ToDo(
            task: task,
            dueDate: dueDate,
            reminderIntent: reminderIntent,
            ownerUserID: ownerUserID
         )
         context.insert(toDo)
         try context.save()
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
         SyncCoordinator.shared.scheduleLocalSync()
         refreshSnapshot()
         send(receipt: WatchToDoActionReceipt(actionID: action.id, accepted: true))
      } catch {
         lastErrorMessage = error.localizedDescription
         send(receipt: WatchToDoActionReceipt(
            actionID: action.id,
            accepted: false,
            message: error.localizedDescription
         ))
      }
   }

   private func apply(action: WatchToDoAction) {
      guard let container = modelContainer else {
         send(receipt: WatchToDoActionReceipt(
            actionID: action.id,
            accepted: false,
            message: "iPhone data store is not ready."
         ))
         return
      }

      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         guard let toDo = toDo(matching: action, in: toDos) else {
            send(receipt: WatchToDoActionReceipt(
               actionID: action.id,
               accepted: false,
               message: "ToDo was not found on iPhone."
            ))
            refreshSnapshot()
            return
         }

         switch action.type {
         case .complete:
            toDo.transition(to: .done)
            LiveActivityService.shared.endActivity(for: toDo)
         case .reopen:
            toDo.transition(to: .active)
         case .setDueDate:
            toDo.dueDate = action.dueDate
            if action.dueDate == nil {
               toDo.reminderIntent = .soft
            } else if action.isTimeSensitive == true {
               toDo.reminderIntent = .timeSensitive
            } else if toDo.reminderIntent == .soft {
               toDo.reminderIntent = .due
            }
            toDo.markUpdated()
         case .snooze:
            let seconds = action.snoozeSeconds ?? 0
            guard seconds > 0 else {
               send(receipt: WatchToDoActionReceipt(
                  actionID: action.id,
                  accepted: false,
                  message: "Choose a snooze duration."
               ))
               return
            }
            toDo.dueDate = Date(timeInterval: seconds, since: max(toDo.dueDate ?? .now, .now))
            if toDo.reminderIntent == .soft {
               toDo.reminderIntent = .due
            }
            toDo.markUpdated()
         case .openOnPhone:
            NavigationCoordinator.shared.notificationRoute = .toDo(
               localIdentifier: action.localIdentifier,
               cloudID: action.cloudID
            )
         case .create, .requestRefresh:
            break
         }

         try context.save()

         SyncCoordinator.shared.showTransientFeedback(
            title: "Watch Update",
            message: "Applied \(action.type.rawValue) to '\(toDo.task)",
            style: .success
         )

         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
         SyncCoordinator.shared.scheduleLocalSync()
         refreshSnapshot()
         send(receipt: WatchToDoActionReceipt(actionID: action.id, accepted: true))
      } catch {
         lastErrorMessage = error.localizedDescription
         send(receipt: WatchToDoActionReceipt(
            actionID: action.id,
            accepted: false,
            message: error.localizedDescription
         ))
      }
   }

   private func toDo(matching action: WatchToDoAction, in toDos: [ToDo]) -> ToDo? {
      if let cloudID = action.cloudID,
         let toDo = toDos.first(where: { $0.cloudID == cloudID }) {
         return toDo
      }

      if let localIdentifier = action.localIdentifier {
         return toDos.first { persistentIdentifierString(for: $0) == localIdentifier }
      }

      return nil
   }

   private func watchSort(_ lhs: ToDo, _ rhs: ToDo) -> Bool {
      if lhs.isDoneState != rhs.isDoneState {
         return !lhs.isDoneState
      }

      let leftDueDate = lhs.dueDate ?? .distantFuture
      let rightDueDate = rhs.dueDate ?? .distantFuture
      if leftDueDate != rightDueDate {
         return leftDueDate < rightDueDate
      }

      return lhs.syncUpdatedAt > rhs.syncUpdatedAt
   }

   private func persistentIdentifierString(for toDo: ToDo) -> String {
      String(describing: toDo.id)
   }

   private func currentAuthState() -> WatchAuthState {
      let authStore = SupabaseAuthStore.shared

      guard authStore.isAuthenticated,
            let userID = authStore.currentUserID else {
         return .offline
      }

      return WatchAuthState(
         isAuthenticated: true,
         userID: userID,
         provider: authStore.accountProviderLabel,
         email: authStore.signedInEmail,
         source: .iPhone
      )
   }

   private func applyState(_ state: WatchSessionSnapshot) {
      isSupported = WCSession.isSupported()
      isPaired = state.isPaired
      isWatchAppInstalled = state.isWatchAppInstalled
      isReachable = state.isReachable
      activationState = state.activationState
   }

   private func canSendToWatch(_ session: WCSession) -> Bool {
      session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
   }

   nonisolated private static func snapshot(from session: WCSession) -> WatchSessionSnapshot {
      WatchSessionSnapshot(
         isPaired: session.isPaired,
         isWatchAppInstalled: session.isWatchAppInstalled,
         isReachable: session.isReachable,
         activationState: session.activationState
      )
   }
}

private extension WatchSyncMode {
   init(_ syncMode: SyncMode) {
      switch syncMode {
      case .deviceOnly:
         self = .deviceOnly
      case .iCloud:
         self = .iCloud
      case .syncEverywhere:
         self = .syncEverywhere
      }
   }
}

extension WatchConnectivityService: WCSessionDelegate {
   nonisolated func session(
      _ session: WCSession,
      activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
   ) {
      let state = Self.snapshot(from: session)
      let errorMessage = error?.localizedDescription
      Task { @MainActor in
         self.applyState(state)
         self.lastErrorMessage = errorMessage
      }
   }

   nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
      let state = Self.snapshot(from: session)
      Task { @MainActor in
         self.applyState(state)
      }
   }

   nonisolated func sessionDidDeactivate(_ session: WCSession) {
      let state = Self.snapshot(from: session)
      session.activate()
      Task { @MainActor in
         self.applyState(state)
      }
   }

   nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
      let state = Self.snapshot(from: session)
      Task { @MainActor in
         self.applyState(state)
      }
   }

   nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
      let state = Self.snapshot(from: session)
      Task { @MainActor in
         self.applyState(state)
      }
   }

   nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
      let envelope = WatchEnvelopeParts(applicationContext)
      Task { @MainActor in
         self.handle(envelope: envelope)
      }
   }

   nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
      let envelope = WatchEnvelopeParts(userInfo)
      Task { @MainActor in
         self.handle(envelope: envelope)
      }
   }

   nonisolated func session(
      _ session: WCSession,
      didReceiveMessage message: [String: Any],
      replyHandler: @escaping ([String: Any]) -> Void
   ) {
      let envelope = WatchEnvelopeParts(message)
      replyHandler(["accepted": true])
      Task { @MainActor in
         self.handle(envelope: envelope)
      }
   }

   nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
      let envelope = WatchEnvelopeParts(message)
      Task { @MainActor in
         self.handle(envelope: envelope)
      }
   }
}
#endif
