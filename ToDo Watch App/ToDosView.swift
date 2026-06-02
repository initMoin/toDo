@preconcurrency import Combine
import AuthenticationServices
import SwiftUI
import WatchKit
import WatchConnectivity

enum WatchAppColor {
   static let main = Color(hex: 0xE9A700)
   static let secondary = Color(hex: 0x006CE7)
   static let white = Color(hex: 0xEBEBEB)
   static let black = Color(hex: 0x393939)
   static let tertiary = Color(hex: 0x62C400)
   static let destructive = Color(hex: 0xD40000)

   static let actionPrimary = main
   static let actionSecondary = secondary
   static let actionSuccess = tertiary
   static let onAction = black

   static let textPrimary = white
   static let textSecondary = Color(hex: 0xAFAFAF)

   static let surface = Color(hex: 0x101010)
   static let surfaceElevated = Color(hex: 0x1C1C1C)
   static let surfaceMuted = Color(hex: 0x2A2A2A)
   static let border = Color.white.opacity(0.12)
}

extension Color {
   init(hex: UInt, opacity: Double = 1) {
      self.init(
         .sRGB,
         red: Double((hex >> 16) & 0xff) / 255,
         green: Double((hex >> 8) & 0xff) / 255,
         blue: Double(hex & 0xff) / 255,
         opacity: opacity
      )
   }
}

extension WatchToDoItem {
   var isOverdue: Bool {
      guard !isDone, let dueDate else { return false }
      return dueDate < .now
   }

   func isDueForInAppReminder(at date: Date) -> Bool {
      guard lifecycleState == .active, !isDone, let dueDate else { return false }
      return dueDate <= date
   }
}

extension Font {
   static func watchDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title3) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func watchTitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title3) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func watchAccent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-Bold", size: size, relativeTo: textStyle)
   }

   static func watchBody(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom(watchBodyFontName(for: textStyle), size: size, relativeTo: textStyle)
   }

   static func watchBodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-Regular", size: size, relativeTo: textStyle)
   }

   private static func watchBodyFontName(for textStyle: Font.TextStyle) -> String {
      switch textStyle {
      case .caption, .caption2, .footnote:
         return "Jura-Regular"
      default:
         return "Jura-Light"
      }
   }
}

//enum WatchSnoozeUnit: String, CaseIterable, Identifiable {
//   case minutes, hours, days, weeks, months, years
//   var id: String { rawValue }
//
//   var title: String {
//      switch self {
//      case .minutes: return "Minutes"
//      case .hours: return "Hours"
//      case .days: return "Days"
//      case .weeks: return "Weeks"
//      case .months: return "Months"
//      case .years: return "Years"
//      }
//   }
//
//   var values: [Int] {
//      switch self {
//      case .minutes: return [5, 15, 30]
//      case .hours, .days, .weeks, .months, .years: return [1, 3, 6]
//      }
//   }
//
//   func label(for value: Int) -> String {
//      let unitLabel = value == 1 ? singularTitle.lowercased() : title.lowercased()
//      return "\(value) \(unitLabel)"
//   }
//
//   func seconds(for value: Int) -> TimeInterval {
//      switch self {
//      case .minutes: return TimeInterval(value * 60)
//      case .hours: return TimeInterval(value * 60 * 60)
//      case .days: return TimeInterval(value * 24 * 60 * 60)
//      case .weeks: return TimeInterval(value * 7 * 24 * 60 * 60)
//      case .months: return TimeInterval(value * 30 * 24 * 60 * 60)
//      case .years: return TimeInterval(value * 365 * 24 * 60 * 60)
//      }
//   }
//
//   private var singularTitle: String {
//      switch self {
//      case .minutes: return "Minute"
//      case .hours: return "Hour"
//      case .days: return "Day"
//      case .weeks: return "Week"
//      case .months: return "Month"
//      case .years: return "Year"
//      }
//   }
//}

enum WatchSnoozeUnit: String, CaseIterable, Identifiable {
   case minutes, hours, days, weeks, months, years
   var id: String { rawValue }

   var title: String { rawValue.capitalized }
   var values: [Int] { [1, 3, 5] }

   func label(for value: Int) -> String {
      let unitLabel = value == 1 ? singularTitle.lowercased() : title.lowercased()
      return "\(value) \(unitLabel)"
   }

   private var singularTitle: String {
      switch self {
      case .minutes: return "Minute"
      case .hours: return "Hour"
      case .days: return "Day"
      case .weeks: return "Week"
      case .months: return "Month"
      case .years: return "Year"
      }
   }

   func seconds(for value: Int) -> TimeInterval {
      let minute: TimeInterval = 60
      let hour = minute * 60
      let day = hour * 24
      switch self {
      case .minutes: return TimeInterval(value) * minute
      case .hours:   return TimeInterval(value) * hour
      case .days:    return TimeInterval(value) * day
      case .weeks:   return TimeInterval(value) * day * 7
      case .months:  return TimeInterval(value) * day * 30
      case .years:   return TimeInterval(value) * day * 365
      }
   }
}

struct WatchSnoozePickerView: View {
   let item: WatchToDoItem
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss

   @State private var selectedValue: Int? = nil

   var body: some View {
      List {
         Section("Snooze Unit") {
            ForEach(WatchSnoozeUnit.allCases) { unit in
               NavigationLink {
                  quantityPicker(for: unit)
               } label: {
                  Text(unit.title)
                     .font(.watchBodyStrong(15, relativeTo: .body))
               }
            }
         }
      }
      .navigationTitle("Snooze")
   }

   private func quantityPicker(for unit: WatchSnoozeUnit) -> some View {
      List {
         Section("Select Duration") {
            ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
               Button {
                  selectedValue = value

                  store.snooze(item, seconds: unit.seconds(for: value))

                  Task {
                     try? await Task.sleep(nanoseconds: 300_000_000)
                     dismiss()
                  }
               } label: {
                  HStack {
                     Text(unit.label(for: value))
                        .font(.watchBodyStrong(15, relativeTo: .body))
                     Spacer()
                     if selectedValue == value {
                        Image(systemName: "checkmark.circle.fill")
                     }
                  }
                  .foregroundStyle(selectedValue == value ? WatchAppColor.actionSuccess : WatchAppColor.actionSecondary)
               }
            }
         }
      }
      .navigationTitle(unit.title)
   }
}

@MainActor
final class WatchToDoStore: NSObject, ObservableObject, WCSessionDelegate {
   @Published private(set) var items: [WatchToDoItem] = []
   @Published private(set) var lastUpdated: Date?
   @Published private(set) var statusText = "Connect iPhone"
   @Published private(set) var pendingActionIDs = Set<UUID>()
   @Published private(set) var queuedActionCount = 0
   @Published private(set) var isCompanionAppInstalled = false
   @Published private(set) var isPhoneReachable = false
   @Published var selectedItem: WatchToDoItem?

   private weak var authStore: WatchAuthStore?
   private let actionQueue = WatchActionQueueStore()
   private let directSyncClient = WatchDirectSyncClient()
   private var isDirectSyncing = false
   private var needsDirectSyncAfterCurrent = false

   private var session: WCSession? {
      guard WCSession.isSupported() else { return nil }
      return .default
   }

   var toDoItems: [WatchToDoItem] {
      items
         .filter { !$0.isDone }
         .sorted(by: prioritizedSort)
   }

   var recentlyDoneItems: [WatchToDoItem] {
      Array(items.filter(\.isDone).sorted { $0.updatedAt > $1.updatedAt }.prefix(4))
   }

   var doneItems: [WatchToDoItem] {
      items.filter(\.isDone).sorted { $0.updatedAt > $1.updatedAt }
   }

   var canOpenOnPhone: Bool {
      isCompanionAppInstalled && isPhoneReachable
   }

   func configure(authStore: WatchAuthStore) {
      self.authStore = authStore

      if ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode") {
         applyScreenshotSampleData()
         return
      }

      guard let session else {
         statusText = "Unavailable"
         return
      }

      session.delegate = self
      updatePhoneAvailability(from: session)

      if session.activationState == .notActivated {
         session.activate()
      }

      handle(envelope: WatchEnvelopeParts(session.receivedApplicationContext))
      queuedActionCount = actionQueue.load().count

      Task {
         await syncDirectlyIfPossible()
      }
   }

   private func applyScreenshotSampleData() {
      let calendar = Calendar.current
      let now = Date()
      items = [
         WatchToDoItem(
            id: "watch-send-invoice",
            cloudID: nil,
            task: "Send invoice",
            isDone: false,
            dueDate: calendar.date(byAdding: .hour, value: -3, to: now),
            isTimeSensitive: true,
            createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-hello-world",
            cloudID: nil,
            task: "Hello world!",
            isDone: false,
            dueDate: calendar.date(byAdding: .hour, value: 4, to: now),
            isTimeSensitive: true,
            createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-groceries",
            cloudID: nil,
            task: "Pick up groceries",
            isDone: false,
            dueDate: calendar.date(byAdding: .hour, value: 8, to: now),
            isTimeSensitive: false,
            createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-review-feedback",
            cloudID: nil,
            task: "Review beta feedback",
            isDone: false,
            dueDate: calendar.date(byAdding: .day, value: 1, to: now),
            isTimeSensitive: false,
            createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -4, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-archive-screenshots",
            cloudID: nil,
            task: "Archive old screenshots",
            isDone: true,
            dueDate: nil,
            isTimeSensitive: false,
            createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -6, to: now) ?? now
         )
      ]
      lastUpdated = now
      statusText = "Updated"
      queuedActionCount = 0
      isCompanionAppInstalled = true
      isPhoneReachable = true
   }

   func requestRefresh() {
      guard let session, session.isReachable else {
         Task { await syncDirectlyIfPossible() }
         return
      }

      sendQueuedActionsToPhoneIfReachable()
      send(action: WatchToDoAction(type: .requestRefresh))
   }

   func select(_ item: WatchToDoItem) {
      selectedItem = item
   }

   func clearSelection() {
      selectedItem = nil
   }

   func create(task: String, dueDate: Date?, isTimeSensitive: Bool) {
      send(action: WatchToDoAction(
         type: .create,
         task: task,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive
      ))
   }

   func updateTask(_ task: String, for item: WatchToDoItem) {
      let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTask.isEmpty, trimmedTask != item.task else { return }

      send(action: WatchToDoAction(
         type: .updateTask,
         item: item,
         task: trimmedTask
      ))
   }

   func complete(_ item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .complete, item: item))
   }

   func reopen(_ item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .reopen, item: item))
   }

   func archive(_ item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .archive, item: item))
      if selectedItem?.id == item.id {
         selectedItem = nil
      }
   }

   func trash(_ item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .trash, item: item))
      if selectedItem?.id == item.id {
         selectedItem = nil
      }
   }

   func completeNanoDo(_ nanoDo: WatchNanoDoItem, in item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .completeNanoDo, item: item, nanoDo: nanoDo))
   }

   func reopenNanoDo(_ nanoDo: WatchNanoDoItem, in item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .reopenNanoDo, item: item, nanoDo: nanoDo))
   }

   func deleteNanoDo(_ nanoDo: WatchNanoDoItem, in item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .deleteNanoDo, item: item, nanoDo: nanoDo))
   }

   func setDueDate(_ dueDate: Date?, for item: WatchToDoItem, isTimeSensitive: Bool? = nil) {
      let resolvedTimeSensitive = isTimeSensitive ?? item.isTimeSensitive
      guard !Self.sameDueDate(item.dueDate, dueDate) || resolvedTimeSensitive != item.isTimeSensitive else {
         return
      }

      send(action: WatchToDoAction(
         type: .setDueDate,
         item: item,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive
      ))
   }

   private static func sameDueDate(_ lhs: Date?, _ rhs: Date?) -> Bool {
      switch (lhs, rhs) {
      case (.none, .none):
         return true
      case let (.some(left), .some(right)):
         return abs(left.timeIntervalSince(right)) < 1
      default:
         return false
      }
   }

   func snooze(_ item: WatchToDoItem, seconds: TimeInterval) {
      send(action: WatchToDoAction(type: .snooze, item: item, snoozeSeconds: seconds))
   }

   func openOnPhone(_ item: WatchToDoItem) {
      guard let session else { return }

      updatePhoneAvailability(from: session)

      guard isCompanionAppInstalled else {
         statusText = "Install iPhone app"
         return
      }

      guard session.isReachable else {
         statusText = "Open toDō on iPhone"
         return
      }

      do {
         let action = WatchToDoAction(type: .openOnPhone, item: item)
         let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
         pendingActionIDs.insert(action.id)
         statusText = "Opening"
         session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
            Task { @MainActor in
               self?.pendingActionIDs.remove(action.id)
               self?.statusText = error.localizedDescription
            }
         }
      } catch {
         statusText = error.localizedDescription
      }
   }

   private func send(action: WatchToDoAction) {
      guard let session else { return }

      do {
         let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
         pendingActionIDs.insert(action.id)
         statusText = session.isReachable ? "Sending" : "Queued"

         if session.isReachable {
            session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
               Task { @MainActor in
                  self?.statusText = error.localizedDescription
               }
            }
         } else {
            actionQueue.enqueue(action)
            queuedActionCount = actionQueue.load().count
            if authStore?.standaloneSession() != nil {
               Task {
                  await syncDirectlyIfPossible()
               }
            } else {
               session.transferUserInfo(envelope)
            }
         }
      } catch {
         statusText = error.localizedDescription
      }
   }

   private func sendQueuedActionsToPhoneIfReachable() {
      guard let session, session.isReachable, isCompanionAppInstalled else { return }

      for action in actionQueue.load() {
         do {
            let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
            pendingActionIDs.insert(action.id)
            session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
               Task { @MainActor in
                  self?.statusText = error.localizedDescription
               }
            }
         } catch {
            statusText = error.localizedDescription
         }
      }
   }

   private func syncDirectlyIfPossible() async {
      guard !isDirectSyncing else {
         needsDirectSyncAfterCurrent = true
         return
      }

      isDirectSyncing = true
      defer {
         isDirectSyncing = false
         if needsDirectSyncAfterCurrent {
            needsDirectSyncAfterCurrent = false
            Task { await syncDirectlyIfPossible() }
         }
      }

      guard let authStore else {
         statusText = queuedActionCount > 0 ? "Queued" : statusText
         return
      }

      guard let directSyncClient else {
         statusText = queuedActionCount > 0 ? "Queued" : statusText
         return
      }

      statusText = "Syncing"

      do {
         guard var session = try await authStore.validStandaloneSession() else {
            statusText = queuedActionCount > 0 ? "Queued" : statusText
            return
         }

         let queuedActions = actionQueue.load()
         var completedActionIDs = Set<UUID>()
         for action in queuedActions {
            do {
               try await directSyncClient.apply(action, session: session)
               completedActionIDs.insert(action.id)
            } catch DirectSyncError.invalidAction {
               continue
            } catch {
               if isExpiredSessionError(error),
                  let refreshedSession = try await authStore.refreshStandaloneSession() {
                  session = refreshedSession
                  try await directSyncClient.apply(action, session: session)
                  completedActionIDs.insert(action.id)
               } else {
                  throw error
               }
            }
         }

         actionQueue.remove(completedActionIDs)
         queuedActionCount = actionQueue.load().count
         do {
            items = try await directSyncClient.fetchToDos(session: session)
         } catch {
            if isExpiredSessionError(error),
               let refreshedSession = try await authStore.refreshStandaloneSession() {
               session = refreshedSession
               items = try await directSyncClient.fetchToDos(session: session)
            } else {
               throw error
            }
         }
         lastUpdated = .now
         statusText = queuedActionCount > 0 ? "Queued" : "Updated"
      } catch {
         queuedActionCount = actionQueue.load().count
         if isExpiredSessionError(error) {
            authStore.expireStandaloneSession()
            statusText = WatchAuthStore.expiredSessionMessage
         } else {
            statusText = error.localizedDescription
         }
      }
   }

   private func isExpiredSessionError(_ error: Error) -> Bool {
      let message = error.localizedDescription.lowercased()
      return message.contains("jwt expired") || message.contains("token is expired")
   }

   private func updatePhoneAvailability(from session: WCSession) {
#if os(watchOS)
      updatePhoneAvailability(isCompanionAppInstalled: session.isCompanionAppInstalled, isPhoneReachable: session.isReachable)
#else
      updatePhoneAvailability(isCompanionAppInstalled: true, isPhoneReachable: session.isReachable)
#endif
   }

   private func updatePhoneAvailability(isCompanionAppInstalled: Bool, isPhoneReachable: Bool) {
      self.isCompanionAppInstalled = isCompanionAppInstalled
      self.isPhoneReachable = isPhoneReachable
   }

   private func handle(envelope: WatchEnvelopeParts) {
      guard let kind = WatchBridgeCodec.decodeKind(
         schemaVersion: envelope.schemaVersion,
         rawKind: envelope.rawKind
      ) else { return }

      do {
         switch kind {
         case .snapshot:
            guard let snapshot = try WatchBridgeCodec.decodePayload(WatchToDoSnapshot.self, from: envelope.payload) else {
               return
            }
            items = snapshot.items
            lastUpdated = snapshot.generatedAt

            authStore?.applyPhoneAuthState(snapshot.authState)
            statusText = snapshot.items.isEmpty ? "No toDōs" : "Updated"
         case .authState:
            guard let authState = try WatchBridgeCodec.decodePayload(WatchAuthState.self, from: envelope.payload) else {
               return
            }
            authStore?.applyPhoneAuthState(authState)
            statusText = authState.isAuthenticated ? "Account Ready" : "Connect iPhone"
         case .actionReceipt:
            guard let receipt = try WatchBridgeCodec.decodePayload(WatchToDoActionReceipt.self, from: envelope.payload) else {
               return
            }
            pendingActionIDs.remove(receipt.actionID)
            actionQueue.remove([receipt.actionID])
            queuedActionCount = actionQueue.load().count
            statusText = receipt.accepted ? "Saved" : (receipt.message ?? "Not saved")
         case .action:
            break
         }
      } catch {
         statusText = error.localizedDescription
      }
   }

   private func prioritizedSort(_ lhs: WatchToDoItem, _ rhs: WatchToDoItem) -> Bool {
      if lhs.isOverdue != rhs.isOverdue {
         return lhs.isOverdue
      }

      let leftDueDate = lhs.dueDate ?? .distantFuture
      let rightDueDate = rhs.dueDate ?? .distantFuture
      if leftDueDate != rightDueDate {
         return leftDueDate < rightDueDate
      }

      if lhs.isTimeSensitive != rhs.isTimeSensitive {
         return lhs.isTimeSensitive
      }

      return lhs.updatedAt > rhs.updatedAt
   }

}

extension WatchToDoStore {
   nonisolated func session(
      _ session: WCSession,
      activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
   ) {
      let errorMessage = error?.localizedDescription
      let receivedApplicationContext = WatchEnvelopeParts(session.receivedApplicationContext)
      Task { @MainActor in
         self.statusText = errorMessage ?? "Connected"
         self.handle(envelope: receivedApplicationContext)

         if activationState == .activated {
            self.requestRefresh()
            self.sendQueuedActionsToPhoneIfReachable()
         }
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

   nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
      let envelope = WatchEnvelopeParts(message)
      Task { @MainActor in
         self.handle(envelope: envelope)
      }
   }

   nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
#if os(watchOS)
      let isCompanionAppInstalled = session.isCompanionAppInstalled
#else
      let isCompanionAppInstalled = true
#endif
      let isPhoneReachable = session.isReachable
      Task { @MainActor in
         self.updatePhoneAvailability(
            isCompanionAppInstalled: isCompanionAppInstalled,
            isPhoneReachable: isPhoneReachable
         )
         self.sendQueuedActionsToPhoneIfReachable()
      }
   }

#if os(iOS)
   nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

   nonisolated func sessionDidDeactivate(_ session: WCSession) {
      session.activate()
   }
#endif
}

struct ToDosView: View {
   @Environment(\.scenePhase) private var scenePhase
   @StateObject private var store = WatchToDoStore()
   @StateObject private var authStore = WatchAuthStore()
   @State private var navigationPath: [WatchRoute] = []
   @State private var didApplyScreenshotPresentation = false
   @State private var reminderNow = Date()
   @State private var dismissedDueReminderIDs = Set<String>()

   private let autoRefreshTimer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
   private let inAppReminderTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

   var body: some View {
      NavigationStack(path: $navigationPath) {
         ScrollView {
            VStack(alignment: .leading, spacing: 8) {
               header
                  .padding(.bottom, 2)

               Button {
                  navigationPath.append(.newToDo)
               } label: {
                  Label("New toDō", systemImage: "plus")
                     .font(.watchBodyStrong(14, relativeTo: .subheadline))
                     .frame(maxWidth: .infinity)
               }
               .buttonStyle(WatchProminentButtonStyle())

               if store.toDoItems.isEmpty {
                  emptyState
               } else {
                  VStack(alignment: .leading, spacing: 6) {
                     ForEach(store.toDoItems) { item in
                        WatchToDoRowActionButton(
                           item: item,
                           accent: WatchAppColor.actionPrimary,
                           onOpen: { store.select(item) },
                           onToggleDone: { item.isDone ? store.reopen(item) : store.complete(item) }
                        )
                     }
                  }
               }

               Button {
                  store.requestRefresh()
               } label: {
                  VStack(spacing: 6) {
                     Image(systemName: "arrow.clockwise")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(WatchAppColor.main)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                        .padding(.bottom, 8)

                     Text(lastUpdatedLabel)
                        .font(.watchBody(10, relativeTo: .caption2))
                        .foregroundStyle(WatchAppColor.textSecondary)
                  }
               }
               .buttonStyle(.plain)
               .padding(.top, 10)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 20)
         }
         .background(WatchAppColor.surface)
         .refreshable {
            store.requestRefresh()
         }
         .navigationDestination(for: WatchRoute.self) { route in
            switch route {
            case .newToDo:
               CaptureToDoView(store: store)
            case .settings:
               WatchAccountView(
                  authStore: authStore,
                  store: store,
                  openDoneToDos: { navigationPath.append(.doneToDos) }
               )
            case .doneToDos:
               WatchDoneToDosView(store: store)
            }
         }
         .onReceive(autoRefreshTimer) { _ in
            store.requestRefresh()
         }
         .onReceive(inAppReminderTimer) { date in
            reminderNow = date
         }
         .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
               reminderNow = Date()
               store.requestRefresh()
            }
         }
      }
      .tint(WatchAppColor.actionPrimary)
      .overlay {
         if let item = store.selectedItem {
            Color.black.opacity(0.28)
               .ignoresSafeArea()
               .onTapGesture {
                  store.clearSelection()
               }
               .transition(.opacity)

            VStack {
               Spacer(minLength: 0)

               WatchToDoDetailView(
                  item: item,
                  store: store,
                  onClose: { store.clearSelection() }
               )
               .frame(maxWidth: .infinity)
               .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
               .overlay(
                  RoundedRectangle(cornerRadius: 28, style: .continuous)
                     .stroke(WatchAppColor.border, lineWidth: 1)
               )
               .shadow(color: .black.opacity(0.45), radius: 18, y: -8)
               .padding(.horizontal, 8)
               .padding(.bottom, 2)
               .transition(.move(edge: .bottom).combined(with: .opacity))
            }
         }
      }
      .animation(.spring(response: 0.34, dampingFraction: 0.86), value: store.selectedItem?.id)
      .overlay(alignment: .bottom) {
         if let item = activeInAppReminder {
            WatchDueReminderBanner(
               item: item,
               now: reminderNow,
               onOpen: { openInAppReminder(item) },
               onDone: { completeInAppReminder(item) },
               onSnooze: { snoozeInAppReminder(item) },
               onDismiss: { dismissInAppReminder(item) }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
         }
      }
      .animation(.spring(response: 0.34, dampingFraction: 0.84), value: activeInAppReminder?.id)
      .onChange(of: activeInAppReminder?.id) { _, newValue in
         guard newValue != nil else { return }
         WKInterfaceDevice.current().play(.notification)
      }
      .task {
         store.configure(authStore: authStore)
         applyScreenshotPresentationIfNeeded()
      }
   }

   private var activeInAppReminder: WatchToDoItem? {
      guard !isRunningForScreenshots else { return nil }
      return store.toDoItems
         .filter { item in
            item.isDueForInAppReminder(at: reminderNow) && !dismissedDueReminderIDs.contains(item.id)
         }
         .sorted { lhs, rhs in
            if lhs.isTimeSensitive != rhs.isTimeSensitive {
               return lhs.isTimeSensitive && !rhs.isTimeSensitive
            }
            return (lhs.dueDate ?? .distantPast) < (rhs.dueDate ?? .distantPast)
         }
         .first
   }

   private func openInAppReminder(_ item: WatchToDoItem) {
      dismissedDueReminderIDs.insert(item.id)
      store.select(item)
   }

   private func completeInAppReminder(_ item: WatchToDoItem) {
      dismissedDueReminderIDs.insert(item.id)
      store.complete(item)
   }

   private func snoozeInAppReminder(_ item: WatchToDoItem) {
      dismissedDueReminderIDs.insert(item.id)
      store.snooze(item, seconds: 15 * 60)
   }

   private func dismissInAppReminder(_ item: WatchToDoItem) {
      dismissedDueReminderIDs.insert(item.id)
   }

   private var isRunningForScreenshots: Bool {
      ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
   }

   private var requestedScreenshotScreen: String? {
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "-ScreenshotScreen"),
            arguments.indices.contains(arguments.index(after: index)) else {
         return nil
      }
      return arguments[arguments.index(after: index)]
   }

   private func applyScreenshotPresentationIfNeeded() {
      guard isRunningForScreenshots, !didApplyScreenshotPresentation else { return }
      didApplyScreenshotPresentation = true

      let screen = requestedScreenshotScreen ?? "todos"
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
         switch screen {
         case "settings":
            navigationPath = [.settings]
         case "todo", "detail":
            if let helloWorld = store.toDoItems.first(where: { $0.task == "Hello world!" }) {
               store.select(helloWorld)
            } else if let firstItem = store.toDoItems.first {
               store.select(firstItem)
            }
         default:
            break
         }
      }
   }

   private var lastUpdatedLabel: String {
      if let last = store.lastUpdated {
         return "Updated \(last.formatted(date: .omitted, time: .shortened))"
      }
      return "Refresh Now"
   }

   private var header: some View {
      HStack(alignment: .center, spacing: 10) {
         VStack(alignment: .leading, spacing: 2) {
            Text("ToD\(Text("ō").foregroundStyle(WatchAppColor.main))")
               .font(.watchDisplay(28, relativeTo: .title2))
               .foregroundStyle(WatchAppColor.textPrimary)

            Text("\(store.toDoItems.count) toDōs")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }
         .accessibilityElement(children: .combine)

         Spacer(minLength: 0)

         Button {
            navigationPath.append(.settings)
         } label: {
            Image(systemName: "gearshape.fill")
               .font(.watchDisplay(17, relativeTo: .headline))
               .frame(width: 34, height: 34)
         }
         .buttonStyle(WatchCircleButtonStyle())
         .accessibilityLabel("Open settings")
      }
      .padding(.top, 4)
   }

   private var statusStrip: some View {
      HStack(spacing: 8) {
         Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)

         Text(store.statusText)
            .font(.watchBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .lineLimit(2)

         Spacer(minLength: 0)

         if store.queuedActionCount > 0 {
            Label("\(store.queuedActionCount)", systemImage: "tray.and.arrow.up.fill")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.main)
         } else if let lastUpdated = store.lastUpdated {
            Text(lastUpdated.formatted(date: .omitted, time: .shortened))
               .font(.watchBodyStrong(10, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
   }

   private var statusColor: Color {
      switch store.statusText {
      case "Updated", "Saved", "Connected", "Account Ready":
         return WatchAppColor.actionSuccess
      case "Sending", "Syncing":
         return WatchAppColor.main
      case "Queued":
         return WatchAppColor.secondary
      default:
         return WatchAppColor.textSecondary
      }
   }

   private var emptyState: some View {
      VStack(alignment: .leading, spacing: 8) {
         Image(systemName: "checklist.unchecked")
            .font(.watchDisplay(24, relativeTo: .title3))
            .foregroundStyle(WatchAppColor.secondary)

         Text("What’s worth doing today?")
            .font(.watchDisplay(20, relativeTo: .headline))
            .foregroundStyle(WatchAppColor.textPrimary)

         Text("Start with your first toDō.")
            .font(.watchBody(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
         RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(WatchAppColor.border, lineWidth: 1)
      )
   }
}

private enum WatchRoute: Hashable {
   case newToDo
   case settings
   case doneToDos
}
