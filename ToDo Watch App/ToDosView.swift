@preconcurrency import Combine
import AuthenticationServices
import SwiftUI
import WatchKit
import WatchConnectivity

enum WatchAppColor {
   static let main = Color(hex: 0xF0B42D)
   static let secondary = Color(hex: 0x6EA4FF)
   static let white = Color(hex: 0xF4F1E8)
   static let black = Color(hex: 0x151515)
   static let tertiary = Color(hex: 0x9BE564)
   static let destructive = Color(hex: 0xFF3B30)

   static let actionPrimary = main
   static let actionSecondary = secondary
   static let actionSuccess = tertiary
   static let onAction = black

   static let textPrimary = white
   static let textSecondary = Color(hex: 0xA9A9A9)
   static let textSecondaryStrong = Color(hex: 0xD6D2C8)

   static let surface = Color(hex: 0x0E1011)
   static let surfaceElevated = Color(hex: 0x1A1C1D)
   static let surfaceMuted = Color(hex: 0x2B2C2E)
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
   static func watchBrand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title3) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func watchDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title3) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func watchTitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title3) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func watchAccent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-SemiBold", size: size, relativeTo: textStyle)
   }

   static func watchBody(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom(watchBodyFontName(for: textStyle), size: size, relativeTo: textStyle)
   }

   static func watchBodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-SemiBold", size: size, relativeTo: textStyle)
   }

   static func watchButton(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func watchUserEntry(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Aleo", size: size, relativeTo: textStyle)
         .weight(.medium)
   }

   private static func watchBodyFontName(for textStyle: Font.TextStyle) -> String {
      "Jura-SemiBold"
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

   var title: String { String(localized: String.LocalizationValue(rawValue.capitalized)) }
   var values: [Int] { [1, 3, 5] }

   func label(for value: Int) -> String {
      let unitLabel = value == 1 ? singularTitle : title
      return String(
         format: String(localized: "%@ %@"),
         WatchLocalization.numberString(value),
         unitLabel
      )
   }

   private var singularTitle: String {
      switch self {
      case .minutes: return String(localized: "Minute")
      case .hours: return String(localized: "Hour")
      case .days: return String(localized: "Day")
      case .weeks: return String(localized: "Week")
      case .months: return String(localized: "Month")
      case .years: return String(localized: "Year")
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
                        Image(systemName: "checkmark")
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
   private weak var authStore: WatchAuthStore?
   private let actionQueue = WatchActionQueueStore()
   private var isConfigured = false

   private var session: WCSession? {
      guard WCSession.isSupported() else { return nil }
      return .default
   }

   var toDoItems: [WatchToDoItem] {
      items
         .filter { $0.lifecycleState == .active && !$0.isDone && $0.trashedAt == nil }
         .sorted(by: prioritizedSort)
   }

   var recentlyDoneItems: [WatchToDoItem] {
      Array(doneVisibleItems.sorted { $0.updatedAt > $1.updatedAt }.prefix(4))
   }

   var doneItems: [WatchToDoItem] {
      doneVisibleItems.sorted { $0.updatedAt > $1.updatedAt }
   }

   private var doneVisibleItems: [WatchToDoItem] {
      items.filter { $0.lifecycleState == .done && $0.isDone && $0.trashedAt == nil }
   }

   var canOpenOnPhone: Bool {
      isCompanionAppInstalled && isPhoneReachable
   }

   func configure(authStore: WatchAuthStore) {
      self.authStore = authStore

      guard !isConfigured else {
         queuedActionCount = actionQueue.load().count
         if let session {
            updatePhoneAvailability(from: session)
         }
         return
      }
      isConfigured = true

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
   }

   private func applyScreenshotSampleData() {
      let calendar = Calendar.current
      let now = Date()
      items = [
         WatchToDoItem(
            id: "watch-ship-todo-testflight",
            cloudID: nil,
            task: "Ship toDō 3.0 TestFlight",
            isDone: false,
            dueDate: calendar.date(byAdding: .hour, value: 4, to: now),
            isTimeSensitive: true,
            createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -2, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-tester-feedback",
            cloudID: nil,
            task: "Triage tester feedback",
            isDone: false,
            dueDate: calendar.date(byAdding: .day, value: 1, to: now),
            isTimeSensitive: false,
            createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -3, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-stats-polish",
            cloudID: nil,
            task: "Polish Stats dashboard",
            isDone: false,
            dueDate: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now),
            isTimeSensitive: false,
            createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -1, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-localization-qa",
            cloudID: nil,
            task: "Finish localization QA notes",
            isDone: false,
            dueDate: calendar.date(byAdding: .hour, value: -3, to: now),
            isTimeSensitive: true,
            createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .hour, value: -4, to: now) ?? now
         ),
         WatchToDoItem(
            id: "watch-lock-build-number",
            cloudID: nil,
            task: "Lock v3.0 build number",
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
         statusText = queuedActionCount > 0 ? "Queued" : "Open toDō on iPhone"
         return
      }

      sendQueuedActionsToPhoneIfReachable()
      send(action: WatchToDoAction(type: .requestRefresh))
   }

   func create(task: String, dueDate: Date?, isTimeSensitive: Bool) {
      send(action: WatchToDoAction(
         type: .create,
         cloudID: UUID(),
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
      items.removeAll { $0.id == item.id }
   }

   func trash(_ item: WatchToDoItem) {
      send(action: WatchToDoAction(type: .trash, item: item))
      items.removeAll { $0.id == item.id }
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
            if isCompanionAppInstalled {
               session.transferUserInfo(envelope)
            }
            statusText = "Queued"
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
      let didActivate = activationState == .activated
      let isReachable = session.isReachable
      Task { @MainActor in
         self.statusText = errorMessage ?? "Connected"
         self.handle(envelope: receivedApplicationContext)

         if didActivate {
            self.sendQueuedActionsToPhoneIfReachable()
            if isReachable {
               self.requestRefresh()
            }
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
   @State private var suppressInAppRemindersUntil: Date?
   @State private var toastMessage: String?
   @State private var finishingRows: [String: WatchToDoItem] = [:]
   @State private var reopeningRows: [String: WatchToDoItem] = [:]
   @State private var completionTasks: [String: Task<Void, Never>] = [:]
   @State private var sentCompletionIDs = Set<String>()

   private let autoRefreshTimer = Timer.publish(every: 3600, on: .main, in: .common).autoconnect()
   private let inAppReminderTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

   var body: some View {
      NavigationStack(path: $navigationPath) {
         WatchHomeView(
            store: store,
            onCreate: { navigationPath.append(.newToDo) },
            onShowAll: { navigationPath.append(.allToDos) },
            onShowStats: { navigationPath.append(.stats) },
            onSettings: { navigationPath.append(.settings) },
            finishingRows: finishingRows,
            reopeningRows: reopeningRows
         )
         .refreshable {
            store.requestRefresh()
         }
         .navigationDestination(for: WatchRoute.self) { route in
            switch route {
            case .allToDos:
               WatchAllToDosView(
                  store: store,
                  displayedItems: displayedToDoItems,
                  lastUpdatedLabel: lastUpdatedLabel,
                  onCreate: { navigationPath.append(.newToDo) },
                  onRefresh: { store.requestRefresh() },
                  onOpen: { item in
                     if finishingRows[item.id] != nil {
                        toggleCompletion(for: item)
                     } else {
                        navigationPath.append(.toDoDetail(item.id))
                     }
                  },
                  onToggleDone: { toggleCompletion(for: $0) },
                  isFinishing: { finishingRows[$0.id] != nil }
               )
            case .newToDo:
               CaptureToDoView(store: store) {
                  suppressInAppRemindersUntil = Date().addingTimeInterval(4)
               }
            case .toDoDetail(let itemID):
               WatchToDoDetailView(
                  itemID: itemID,
                  store: store,
                  onDeleted: { message in
                     showToast(message)
                  }
               )
            case .settings:
               WatchAccountView(
                  authStore: authStore,
                  store: store,
                  openDoneToDos: { navigationPath.append(.doneToDos) }
               )
            case .doneToDos:
               WatchDoneToDosView(store: store)
            case .stats:
               WatchStatsView(store: store)
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
      .disabled(activeInAppReminder != nil)
      .tint(WatchAppColor.actionPrimary)
      .overlay {
         if activeInAppReminder != nil, toastMessage == nil {
            Color.black.opacity(0.69)
               .ignoresSafeArea()
               .contentShape(Rectangle())
               .transition(.opacity)
         }
      }
      .overlay(alignment: .bottom) {
         if let toastMessage {
            WatchToastView(message: toastMessage)
               .padding(.horizontal, 8)
               .padding(.bottom, 6)
               .transition(.move(edge: .bottom).combined(with: .opacity))
         } else if let item = activeInAppReminder {
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
	      .accessibilityIdentifier("watch.root")
	   }

   private var displayedToDoItems: [WatchToDoItem] {
      let activeItems = store.toDoItems
      let activeIDs = Set(activeItems.map(\.id))
      let visibleActiveItems = activeItems.map { item in
         reopeningRows[item.id] ?? finishingRows[item.id] ?? item
      }
      let finishingItems = finishingRows.values
         .filter { !activeIDs.contains($0.id) && reopeningRows[$0.id] == nil }
         .sorted { $0.updatedAt > $1.updatedAt }
      let reopeningItems = reopeningRows.values
         .filter { !activeIDs.contains($0.id) }
         .sorted { $0.updatedAt > $1.updatedAt }
      return visibleActiveItems + reopeningItems + finishingItems
   }

   private func toggleCompletion(for item: WatchToDoItem) {
      if item.isDone || finishingRows[item.id] != nil {
         completionTasks[item.id]?.cancel()
         completionTasks[item.id] = nil

         let shouldSendReopen = sentCompletionIDs.contains(item.id) || item.isDone
         withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            finishingRows[item.id] = nil
            reopeningRows[item.id] = activeDisplayItem(from: item)
         }
         if shouldSendReopen {
            store.reopen(item)
         }
         sentCompletionIDs.remove(item.id)

         Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            withAnimation(.easeInOut(duration: 0.22)) {
               reopeningRows[item.id] = nil
            }
         }
         return
      }

      completionTasks[item.id]?.cancel()
      reopeningRows[item.id] = nil
      withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
         finishingRows[item.id] = completingDisplayItem(from: item)
      }
      WKInterfaceDevice.current().play(.success)

      completionTasks[item.id] = Task { @MainActor in
         try? await Task.sleep(for: .milliseconds(180))
         guard !Task.isCancelled else { return }
         guard finishingRows[item.id] != nil else { return }
         store.complete(item)
         sentCompletionIDs.insert(item.id)

         try? await Task.sleep(for: .milliseconds(2600))
         guard !Task.isCancelled else { return }
         withAnimation(.easeInOut(duration: 0.28)) {
            finishingRows[item.id] = nil
         }
         completionTasks[item.id] = nil
         sentCompletionIDs.remove(item.id)
      }
   }

   private func completingDisplayItem(from item: WatchToDoItem) -> WatchToDoItem {
      WatchToDoItem(
         id: item.id,
         cloudID: item.cloudID,
         task: item.task,
         isDone: true,
         lifecycleState: .done,
         trashedAt: item.trashedAt,
         dueDate: item.dueDate,
         isTimeSensitive: item.isTimeSensitive,
         createdAt: item.createdAt,
         updatedAt: .now,
         nanoDos: item.nanoDos
      )
   }

   private func activeDisplayItem(from item: WatchToDoItem) -> WatchToDoItem {
      WatchToDoItem(
         id: item.id,
         cloudID: item.cloudID,
         task: item.task,
         isDone: false,
         lifecycleState: .active,
         trashedAt: item.trashedAt,
         dueDate: item.dueDate,
         isTimeSensitive: item.isTimeSensitive,
         createdAt: item.createdAt,
         updatedAt: .now,
         nanoDos: item.nanoDos
      )
   }

   private func showToast(_ message: String) {
      toastMessage = message
      WKInterfaceDevice.current().play(.success)
      Task {
         try? await Task.sleep(nanoseconds: 1_450_000_000)
         await MainActor.run {
            guard toastMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
               toastMessage = nil
            }
         }
      }
   }

   private var activeInAppReminder: WatchToDoItem? {
      guard !isRunningForScreenshots else { return nil }
      if let suppressInAppRemindersUntil, Date() < suppressInAppRemindersUntil {
         return nil
      }
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
      navigationPath.append(.toDoDetail(item.id))
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

      let screen = requestedScreenshotScreen ?? "home"
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
         switch screen {
         case "home":
            navigationPath = []
         case "todos", "all":
            navigationPath = [.allToDos]
         case "create", "new":
            navigationPath = [.newToDo]
         case "stats":
            navigationPath = [.stats]
         case "settings":
            navigationPath = [.settings]
         case "todo", "detail":
            if let showcase = store.toDoItems.first(where: { $0.task == "Ship toDō 3.0 TestFlight" }) {
               navigationPath = [.toDoDetail(showcase.id)]
            } else if let firstItem = store.toDoItems.first {
               navigationPath = [.toDoDetail(firstItem.id)]
            }
         default:
            break
         }
      }
   }

   private var lastUpdatedLabel: String {
      if let last = store.lastUpdated {
         return String(format: String(localized: "Updated %@"), WatchLocalization.timeString(last))
      }
      return String(localized: "Refresh Now")
   }

   private var statusStrip: some View {
      HStack(spacing: 8) {
         Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)

         Text(LocalizedStringKey(store.statusText))
            .font(.watchBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .lineLimit(2)

         Spacer(minLength: 0)

         if store.queuedActionCount > 0 {
            Label(WatchLocalization.numberString(store.queuedActionCount), systemImage: "tray.and.arrow.up.fill")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.main)
         } else if let lastUpdated = store.lastUpdated {
            Text(WatchLocalization.timeString(lastUpdated))
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
   }
}

private struct WatchHomeView: View {
   @ObservedObject var store: WatchToDoStore
   let onCreate: () -> Void
   let onShowAll: () -> Void
   let onShowStats: () -> Void
   let onSettings: () -> Void
   let finishingRows: [String: WatchToDoItem]
   let reopeningRows: [String: WatchToDoItem]

   private var activeItems: [WatchToDoItem] {
      let activeItems = store.toDoItems
      return Array(activeItems.map { reopeningRows[$0.id] ?? finishingRows[$0.id] ?? $0 }.prefix(3))
   }

   var body: some View {
	      ScrollView {
	         VStack(alignment: .leading, spacing: 10) {
            WatchRootHeader(
               toDoCount: store.toDoItems.count,
               onSettings: onSettings
            )

            WatchCard(spacing: 10) {
               Text("What matters now?")
                  .font(.watchBodyStrong(19, relativeTo: .headline))
                  .fontWeight(.black)
                  .foregroundStyle(WatchAppColor.textPrimary)

               Button(action: onCreate) {
                  HStack(spacing: 7) {
                     Image(systemName: "plus")
                     Text("New toDō")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                  }
                     .frame(maxWidth: .infinity)
               }
               .buttonStyle(WatchHomeActionButtonStyle(
                  foreground: WatchAppColor.onAction,
                  fill: WatchAppColor.actionPrimary,
                  pressedFill: WatchAppColor.secondary,
                  height: 54
               ))

               Button(action: onShowAll) {
                  HStack(spacing: 6) {
                     Image(systemName: "list.bullet")
                     Text("See all toDōs")
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                     Spacer(minLength: 2)
                     if store.toDoItems.count > 0 {
                        Text(WatchLocalization.numberString(store.toDoItems.count))
                           .font(.watchBodyStrong(13, relativeTo: .caption))
                           .fontWeight(.black)
                           .lineLimit(1)
                           .padding(.horizontal, 7)
                           .padding(.vertical, 4)
                           .background(WatchAppColor.surfaceMuted, in: Capsule())
                     }
                  }
               }
               .buttonStyle(WatchHomeActionButtonStyle(
                  foreground: WatchAppColor.secondary,
                  fill: WatchAppColor.secondary.opacity(0.13),
                  pressedFill: WatchAppColor.secondary.opacity(0.24),
                  height: 54
               ))
            }

            HStack(alignment: .center, spacing: 8) {
               Text("Momentum")
                  .font(.watchDisplay(22, relativeTo: .title3))
                  .foregroundStyle(WatchAppColor.textPrimary)

               Spacer(minLength: 0)

               Button(action: onShowStats) {
                  Label("Stats", systemImage: "chart.bar.xaxis")
               }
               .buttonStyle(WatchFilledButtonStyle(fill: WatchAppColor.actionSuccess))
            }

            WatchMetricGrid(items: WatchStatsSnapshot(store: store).homeMetrics)

            if !activeItems.isEmpty {
               VStack(alignment: .leading, spacing: 7) {
                  Text("Up next")
                     .font(.watchDisplay(20, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  ForEach(activeItems) { item in
                     WatchToDoRow(
                        item: item,
                        accent: WatchAppColor.actionPrimary,
                        onOpen: nil,
                        onToggleDone: nil
                     )
                  }
               }
            }
         }
	         .padding(.horizontal, 6)
	         .padding(.bottom, 20)
	      }
	      .background(WatchAppColor.surface)
	      .accessibilityIdentifier("watch.home")
	   }
}

private struct WatchAllToDosView: View {
   @ObservedObject var store: WatchToDoStore
   let displayedItems: [WatchToDoItem]
   let lastUpdatedLabel: String
   let onCreate: () -> Void
   let onRefresh: () -> Void
   let onOpen: (WatchToDoItem) -> Void
   let onToggleDone: (WatchToDoItem) -> Void
   let isFinishing: (WatchToDoItem) -> Bool

   var body: some View {
	      ScrollView {
	         VStack(alignment: .leading, spacing: 8) {
            WatchScreenHeader(
               title: "toDōs",
               subtitle: WatchLocalization.localizedCount(store.toDoItems.count, singularKey: "%@ toDō", pluralKey: "%@ toDōs"),
               systemImage: "list.bullet",
               accent: WatchAppColor.main
            )

            Button(action: onCreate) {
               Label("New toDō", systemImage: "plus")
                  .font(.watchButton(20, relativeTo: .title3))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchProminentButtonStyle())

            if displayedItems.isEmpty {
               WatchEmptyToDoState()
            } else {
               VStack(alignment: .leading, spacing: 6) {
                  ForEach(displayedItems) { item in
                     WatchToDoRowActionButton(
                        item: item,
                        accent: WatchAppColor.actionPrimary,
                        onOpen: { onOpen(item) },
                        onToggleDone: { onToggleDone(item) }
                     )
                     .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.92))
                     ))
                  }
               }
            }

            Button(action: onRefresh) {
               VStack(spacing: 6) {
                  Image(systemName: "arrow.clockwise")
                     .font(.system(size: 24, weight: .bold))
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
	      .accessibilityIdentifier("watch.todos")
	   }
}

private struct WatchRootHeader: View {
   let toDoCount: Int
   let onSettings: () -> Void

   var body: some View {
      HStack(alignment: .center, spacing: 10) {
         VStack(alignment: .leading, spacing: 2) {
            Text("toD\(Text("ō").foregroundStyle(WatchAppColor.main))")
               .font(.watchBrand(28, relativeTo: .title2))
               .foregroundStyle(WatchAppColor.textPrimary)

            Text(WatchLocalization.localizedCount(toDoCount, singularKey: "%@ toDō", pluralKey: "%@ toDōs"))
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }
         .accessibilityElement(children: .combine)

         Spacer(minLength: 0)

         Button(action: onSettings) {
            Image(systemName: "gearshape.fill")
               .font(.watchDisplay(19, relativeTo: .headline))
               .frame(width: 34, height: 34)
         }
         .buttonStyle(WatchCircleButtonStyle())
         .accessibilityLabel("Open settings")
      }
      .padding(.top, 4)
   }
}

private struct WatchEmptyToDoState: View {
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         Image(systemName: "checklist.unchecked")
            .font(.watchDisplay(26, relativeTo: .title3))
            .foregroundStyle(WatchAppColor.secondary)

         Text("What’s worth doing today?")
            .font(.watchDisplay(22, relativeTo: .headline))
            .foregroundStyle(WatchAppColor.textPrimary)

         Text("Start with your first toDō.")
            .font(.watchBody(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
   }
}

private struct WatchStatsView: View {
   @ObservedObject var store: WatchToDoStore

   private var snapshot: WatchStatsSnapshot {
      WatchStatsSnapshot(store: store)
   }

   var body: some View {
	      ScrollView {
	         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Stats",
               subtitle: "Momentum on your wrist.",
               systemImage: "chart.bar.xaxis",
               accent: WatchAppColor.actionSuccess
            )

            WatchMetricGrid(items: snapshot.primaryMetrics)

            WatchActionGroup(title: "Timing", systemImage: "clock", accent: WatchAppColor.main, cardSpacing: 8) {
               WatchStatLine(title: "Due soon", value: WatchLocalization.numberString(snapshot.dueSoon), systemImage: "clock.fill", tint: WatchAppColor.main)
               WatchStatLine(title: "Overdue", value: WatchLocalization.numberString(snapshot.overdue), systemImage: "exclamationmark.circle.fill", tint: WatchAppColor.destructive)
               WatchStatLine(title: "Time-sensitive", value: WatchLocalization.numberString(snapshot.timeSensitive), systemImage: "flame.fill", tint: WatchAppColor.destructive)
            }

            WatchActionGroup(title: "Shape", systemImage: "square.grid.2x2.fill", accent: WatchAppColor.secondary, cardSpacing: 8) {
               WatchStatLine(title: "Active", value: WatchLocalization.numberString(snapshot.active), systemImage: "bolt.fill", tint: WatchAppColor.secondary)
               WatchStatLine(title: "Done", value: WatchLocalization.numberString(snapshot.done), systemImage: "checkmark.circle.fill", tint: WatchAppColor.actionSuccess)
               WatchStatLine(title: "NanoDos", value: WatchLocalization.numberString(snapshot.nanoDos), systemImage: "smallcircle.filled.circle", tint: WatchAppColor.main)
            }
         }
         .padding(.horizontal, 6)
	         .padding(.bottom, 20)
	      }
	      .background(WatchAppColor.surface)
	      .accessibilityIdentifier("watch.stats")
	   }
}

private struct WatchStatsSnapshot {
   let active: Int
   let done: Int
   let overdue: Int
   let dueSoon: Int
   let timeSensitive: Int
   let nanoDos: Int

   init(store: WatchToDoStore, now: Date = .now) {
      let activeItems = store.toDoItems
      active = activeItems.count
      done = store.doneItems.count
      overdue = activeItems.filter(\.isOverdue).count
      dueSoon = activeItems.filter { item in
         guard !item.isOverdue, let dueDate = item.dueDate else { return false }
         return dueDate <= now.addingTimeInterval(24 * 60 * 60)
      }.count
      timeSensitive = activeItems.filter(\.isTimeSensitive).count
      nanoDos = activeItems.reduce(0) { $0 + $1.nanoDos.count }
   }

   var homeMetrics: [WatchMetricItem] {
      [
         WatchMetricItem(title: "Active", value: active, systemImage: "bolt.fill", tint: WatchAppColor.secondary),
         WatchMetricItem(title: "Due soon", value: dueSoon, systemImage: "clock.fill", tint: WatchAppColor.main),
         WatchMetricItem(title: "Overdue", value: overdue, systemImage: "exclamationmark.circle.fill", tint: WatchAppColor.destructive),
         WatchMetricItem(title: "Done", value: done, systemImage: "checkmark.circle.fill", tint: WatchAppColor.actionSuccess)
      ]
   }

   var primaryMetrics: [WatchMetricItem] {
      [
         WatchMetricItem(title: "Active", value: active, systemImage: "bolt.fill", tint: WatchAppColor.secondary),
         WatchMetricItem(title: "Done", value: done, systemImage: "checkmark.circle.fill", tint: WatchAppColor.actionSuccess),
         WatchMetricItem(title: "Overdue", value: overdue, systemImage: "exclamationmark.circle.fill", tint: WatchAppColor.destructive),
         WatchMetricItem(title: "NanoDos", value: nanoDos, systemImage: "smallcircle.filled.circle", tint: WatchAppColor.main)
      ]
   }
}

private struct WatchMetricItem: Identifiable {
   let id = UUID()
   let title: LocalizedStringKey
   let value: Int
   let systemImage: String
   let tint: Color
}

private struct WatchMetricGrid: View {
   let items: [WatchMetricItem]
   private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

   var body: some View {
      LazyVGrid(columns: columns, spacing: 8) {
         ForEach(items) { item in
            VStack(alignment: .leading, spacing: 7) {
               HStack(alignment: .center, spacing: 6) {
                  Text(WatchLocalization.numberString(item.value))
                     .font(.watchDisplay(26, relativeTo: .title2))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineLimit(1)
                     .minimumScaleFactor(0.72)

                  Spacer(minLength: 0)

                  Image(systemName: item.systemImage)
                     .font(.system(size: 12, weight: .black, design: .rounded))
                     .foregroundStyle(item.tint)
                     .frame(width: 24, height: 24)
                     .background(item.tint.opacity(0.16), in: Circle())
               }

               Text(item.title)
                  .font(.watchBodyStrong(13, relativeTo: .caption))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.82)
            }
            .padding(10)
            .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
         }
      }
   }
}

private struct WatchStatLine: View {
   let title: LocalizedStringKey
   let value: String
   let systemImage: String
   let tint: Color

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: systemImage)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
            .background(tint.opacity(0.16), in: Circle())

         Text(title)
            .font(.watchBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)

         Spacer(minLength: 0)

         Text(value)
            .font(.watchDisplay(20, relativeTo: .headline))
            .foregroundStyle(WatchAppColor.textPrimary)
      }
   }
}

enum WatchRoute: Hashable {
   case allToDos
   case newToDo
   case toDoDetail(String)
   case settings
   case doneToDos
   case stats
}
