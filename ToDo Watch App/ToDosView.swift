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
   static func watchBrand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func watchViewTitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
      .custom("Cal Sans UI", size: size, relativeTo: textStyle)
         .weight(.bold)
   }

   static func watchDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title2) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func watchTitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
      .custom("Jura", size: size, relativeTo: textStyle)
         .weight(.bold)
   }

   static func watchAccent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura", size: size, relativeTo: textStyle)
         .weight(.medium)
   }

   static func watchBody(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura", size: size, relativeTo: textStyle)
         .weight(.regular)
   }

   static func watchBodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura", size: size, relativeTo: textStyle)
         .weight(.semibold)
   }

   static func watchButton(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func watchUserEntry(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Aleo", size: size, relativeTo: textStyle)
         .weight(.medium)
   }

   static func watchBadge(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .caption) -> Font {
      .custom("Jura", size: size, relativeTo: textStyle)
         .weight(.bold)
   }

   static func watchLongForm(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Aleo", size: size, relativeTo: textStyle)
         .weight(.regular)
         .italic()
   }

   // SF Symbols retain the system font; release-history values intentionally
   // remain monospaced while customer-facing prose uses the shared roles.
   static func watchSymbol(_ size: CGFloat, weight: Font.Weight = .bold, design: Font.Design = .rounded) -> Font {
      .system(size: size, weight: weight, design: design)
   }

   static func watchCode(_ textStyle: Font.TextStyle = .caption2) -> Font {
      .system(textStyle, design: .monospaced)
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

struct WatchDuplicateReviewRow: Identifiable, Hashable {
   let id: UUID
   let task: String
   let dueDate: Date?
   let duplicateTask: String?

   var hasDuplicate: Bool { duplicateTask != nil }
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
   private let directSyncClient = WatchDirectSyncClient()
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

   var hasQueuedLocalActions: Bool {
      !actionQueue.load().isEmpty
   }

   var queuedCreateActions: [WatchToDoAction] {
      actionQueue.load().filter { $0.type == .create }
   }

   func clearAllForAccountDeletion() {
      items = []
      lastUpdated = nil
      pendingActionIDs.removeAll()
      actionQueue.clear()
      queuedActionCount = 0
      statusText = "Connect iPhone"
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
         if let standaloneSession = authStore?.standaloneSession,
            authStore?.hasResolvedAccount == true {
            refreshDirectly(authSession: standaloneSession)
         } else if authStore?.standaloneSession != nil {
            statusText = "Finish account setup on another device"
         } else {
            statusText = queuedActionCount > 0 ? "Queued" : "Open toDō on iPhone"
         }
         return
      }

      sendQueuedActionsToPhoneIfReachable()
      send(action: WatchToDoAction(type: .requestRefresh))
   }

   func create(
      task: String,
      dueDate: Date?,
      isTimeSensitive: Bool,
      notes: String = "",
      tagNames: [String] = [],
      recurrenceUnitRaw: String? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceModeRaw: String? = nil,
      recurrenceCount: Int? = nil,
      locationReminderLatitude: Double? = nil,
      locationReminderLongitude: Double? = nil,
      locationReminderRadius: Double? = nil,
      locationReminderTriggerRaw: String? = nil,
      locationReminderLabel: String? = nil,
      nanoDoTasks: [String] = []
   ) {
      send(action: WatchToDoAction(
         type: .create,
         cloudID: UUID(),
         task: task,
         notes: notes,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive,
         tagNames: tagNames,
         recurrenceUnitRaw: recurrenceUnitRaw,
         recurrenceInterval: recurrenceInterval,
         recurrenceModeRaw: recurrenceModeRaw,
         recurrenceCount: recurrenceCount,
         locationReminderLatitude: locationReminderLatitude,
         locationReminderLongitude: locationReminderLongitude,
         locationReminderRadius: locationReminderRadius,
         locationReminderTriggerRaw: locationReminderTriggerRaw,
         locationReminderLabel: locationReminderLabel,
         nanoDoTasks: nanoDoTasks
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

   func updateNotes(_ notes: String, for item: WatchToDoItem) {
      let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmedNotes != item.notes.trimmingCharacters(in: .whitespacesAndNewlines) else { return }

      send(action: WatchToDoAction(
         type: .updateNotes,
         item: item,
         notes: trimmedNotes
      ))
   }

   func updateTags(_ tagNames: [String], for item: WatchToDoItem) {
      let names = Self.sanitizedTagNames(tagNames)
      guard names != Self.sanitizedTagNames(item.tags.map(\.name)) else { return }

      send(action: WatchToDoAction(
         type: .updateTags,
         item: item,
         tagNames: names
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

   func createNanoDo(_ task: String, in item: WatchToDoItem) {
      let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTask.isEmpty else { return }

      send(action: WatchToDoAction(
         type: .createNanoDo,
         item: item,
         nanoDoTask: trimmedTask
      ))
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

   func setRecurrence(
      enabled: Bool,
      unitRaw: String?,
      interval: Int?,
      modeRaw: String?,
      count: Int?,
      for item: WatchToDoItem,
      anchorDueDate: Date? = nil
   ) {
      send(action: WatchToDoAction(
         type: .setRecurrence,
         item: item,
         dueDate: anchorDueDate ?? item.dueDate,
         recurrenceUnitRaw: enabled ? unitRaw : nil,
         recurrenceInterval: enabled ? interval : nil,
         recurrenceModeRaw: enabled ? modeRaw : nil,
         recurrenceCount: enabled ? count : nil
      ))
   }

   func setLocationReminder(
      enabled: Bool,
      latitude: Double?,
      longitude: Double?,
      radius: Double,
      triggerRaw: String,
      label: String,
      for item: WatchToDoItem
   ) {
      send(action: WatchToDoAction(
         type: .setLocationReminder,
         item: item,
         locationReminderLatitude: enabled ? latitude : nil,
         locationReminderLongitude: enabled ? longitude : nil,
         locationReminderRadius: enabled ? radius : nil,
         locationReminderTriggerRaw: enabled ? triggerRaw : nil,
         locationReminderLabel: enabled ? label : nil
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

   private static func sanitizedTagNames(_ names: [String]) -> [String] {
      var seen = Set<String>()
      return names
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
         .filter { !$0.isEmpty }
         .filter { seen.insert($0).inserted }
         .prefix(5)
         .map(\.self)
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
      do {
         pendingActionIDs.insert(action.id)
         let canSendToPhone = session?.isReachable == true && isCompanionAppInstalled
         statusText = canSendToPhone ? "Sending" : "Queued"

         if canSendToPhone, let session {
            let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
            session.sendMessage(envelope, replyHandler: nil) { [weak self] error in
               Task { @MainActor in
                  self?.pendingActionIDs.remove(action.id)
                  self?.statusText = error.localizedDescription
               }
            }
         } else if let standaloneSession = authStore?.standaloneSession,
                   authStore?.hasResolvedAccount == true {
            applyDirectly(action, authSession: standaloneSession)
         } else if authStore?.standaloneSession != nil {
            pendingActionIDs.remove(action.id)
            statusText = "Finish account setup on another device"
         } else {
            let envelope = try WatchBridgeCodec.envelope(kind: .action, payload: action)
            actionQueue.enqueue(action)
            queuedActionCount = actionQueue.load().count
            if isCompanionAppInstalled, let session {
               session.transferUserInfo(envelope)
            }
            statusText = "Queued"
         }
      } catch {
         statusText = error.localizedDescription
      }
   }

   private func refreshDirectly(authSession: WatchAuthSession) {
      guard let directSyncClient else {
         statusText = "Direct sync unavailable"
         return
      }

      statusText = "Syncing"
      Task {
         do {
            let remoteItems = try await directSyncClient.fetchToDos(authSession: authSession)
            await MainActor.run {
               items = remoteItems
               lastUpdated = .now
               statusText = remoteItems.isEmpty ? "No toDōs" : "Updated"
            }
         } catch {
            await MainActor.run {
               statusText = error.localizedDescription
            }
         }
      }
   }

   private func applyDirectly(_ action: WatchToDoAction, authSession: WatchAuthSession) {
      guard let directSyncClient else {
         statusText = "Direct sync unavailable"
         pendingActionIDs.remove(action.id)
         return
      }

      if action.type == .create, let optimisticItem = optimisticCreatedItem(from: action) {
         withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            items.removeAll { $0.cloudID == optimisticItem.cloudID }
            items.insert(optimisticItem, at: 0)
         }
      }

      statusText = "Syncing"
      Task {
         do {
            try await directSyncClient.apply(action, authSession: authSession)
            let remoteItems = try await directSyncClient.fetchToDos(authSession: authSession)
            await MainActor.run {
               items = remoteItems
               lastUpdated = .now
               pendingActionIDs.remove(action.id)
               statusText = "Saved"
               AppLog.info("Watch direct sync applied: action=\(action.type.rawValue), fetched=\(remoteItems.count)", logger: AppLog.sync)
            }
         } catch {
            await MainActor.run {
               if action.type == .create, let cloudID = action.cloudID {
                  items.removeAll { $0.cloudID == cloudID }
               }
               pendingActionIDs.remove(action.id)
               statusText = error.localizedDescription
               AppLog.error("Watch direct sync failed: action=\(action.type.rawValue), error=\(error.localizedDescription)", logger: AppLog.sync)
            }
         }
      }
   }

   private func optimisticCreatedItem(from action: WatchToDoAction) -> WatchToDoItem? {
      guard let cloudID = action.cloudID else { return nil }
      let trimmedTask = action.task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let task = trimmedTask.isEmpty ? String(localized: "New toDō") : trimmedTask
      let now = Date()
      let tags = (action.tagNames ?? [])
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
         .filter { !$0.isEmpty }
         .map { WatchTagItem(id: UUID().uuidString, cloudID: nil, name: $0) }
      let nanoDos = (action.nanoDoTasks ?? [])
         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }
         .map { WatchNanoDoItem(id: UUID().uuidString, cloudID: nil, task: $0, isDone: false, dueDate: nil, updatedAt: now) }

      return WatchToDoItem(
         id: cloudID.uuidString,
         cloudID: cloudID,
         task: task,
         isDone: false,
         lifecycleState: .active,
         trashedAt: nil,
         dueDate: action.dueDate,
         isTimeSensitive: action.isTimeSensitive == true,
         createdAt: now,
         updatedAt: now,
         notes: action.notes ?? "",
         tags: tags,
         recurrenceSummary: nil,
         hasLocationReminder: action.locationReminderLatitude != nil && action.locationReminderLongitude != nil,
         locationReminderLabel: action.locationReminderLabel,
         locationReminderTriggerTitle: nil,
         locationReminderLatitude: action.locationReminderLatitude,
         locationReminderLongitude: action.locationReminderLongitude,
         locationReminderRadius: action.locationReminderRadius,
         locationReminderTriggerRaw: action.locationReminderTriggerRaw,
         completeWhenAllNanoDosDone: false,
         nanoDos: nanoDos
      )
   }

   private func sendQueuedActionsToPhoneIfReachable() {
      guard authStore?.standaloneSession == nil else { return }
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

   func mergeQueuedLocalActionsDirectly() async -> Bool {
      guard authStore?.hasResolvedAccount == true,
            let authSession = authStore?.standaloneSession else {
         statusText = "Sign in first"
         return false
      }
      guard let directSyncClient else {
         statusText = "Direct sync unavailable"
         return false
      }

      let queuedActions = actionQueue.load()
      guard !queuedActions.isEmpty else {
         statusText = "No local toDōs"
         return false
      }

      statusText = "Merging"
      do {
         for action in queuedActions {
            try await directSyncClient.apply(action, authSession: authSession)
         }
         let remoteItems = try await directSyncClient.fetchToDos(authSession: authSession)
         actionQueue.clear()
         queuedActionCount = 0
         items = remoteItems
         lastUpdated = .now
         statusText = "Merged"
         return true
      } catch {
         statusText = error.localizedDescription
         AppLog.error("Watch queued merge failed: error=\(error.localizedDescription)", logger: AppLog.sync)
         return false
      }
   }

   func keepQueuedLocalActionsSeparateForNow() {
      statusText = "Kept separate"
   }

   func discardQueuedLocalActions() {
      actionQueue.clear()
      queuedActionCount = 0
      statusText = "Cleared"
   }

   func duplicateReviewRows() -> [WatchDuplicateReviewRow] {
      let activeItems = toDoItems
      return queuedCreateActions.map { action in
         let title = action.task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(localized: "New toDō")
         let normalizedTitle = Self.normalizedDuplicateKey(title)
         let match = activeItems.first { Self.normalizedDuplicateKey($0.task) == normalizedTitle }
         return WatchDuplicateReviewRow(
            id: action.id,
            task: title,
            dueDate: action.dueDate,
            duplicateTask: match?.task
         )
      }
   }

   private static func normalizedDuplicateKey(_ value: String) -> String {
      value
         .trimmingCharacters(in: .whitespacesAndNewlines)
         .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
         .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
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
            authState: authStore.authState,
            onProfile: { navigationPath.append(.profile) },
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
            case .profile:
               WatchProfileView(authStore: authStore, store: store)
            case .migrationReview:
               WatchQueuedMigrationReviewView(store: store)
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
         authStore.start()
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
         completedAt: .now,
         notes: item.notes,
         tags: item.tags,
         recurrenceSummary: item.recurrenceSummary,
         hasLocationReminder: item.hasLocationReminder,
         locationReminderLabel: item.locationReminderLabel,
         locationReminderTriggerTitle: item.locationReminderTriggerTitle,
         completeWhenAllNanoDosDone: item.completeWhenAllNanoDosDone,
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
         completedAt: nil,
         notes: item.notes,
         tags: item.tags,
         recurrenceSummary: item.recurrenceSummary,
         hasLocationReminder: item.hasLocationReminder,
         locationReminderLabel: item.locationReminderLabel,
         locationReminderTriggerTitle: item.locationReminderTriggerTitle,
         completeWhenAllNanoDosDone: item.completeWhenAllNanoDosDone,
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

private enum WatchToDoFilter: String, CaseIterable, Identifiable {
   case recent
   case dueSoon
   case timeSensitive

   var id: String { rawValue }

   var title: LocalizedStringKey {
      switch self {
      case .recent:
         return "Recent"
      case .dueSoon:
         return "Due soon"
      case .timeSensitive:
         return "Time-sensitive"
      }
   }

   var tint: Color {
      switch self {
      case .recent:
         return WatchAppColor.secondary
      case .dueSoon:
         return WatchAppColor.main
      case .timeSensitive:
         return WatchAppColor.destructive
      }
   }
}

private struct WatchHomeView: View {
   @ObservedObject var store: WatchToDoStore
   let onCreate: () -> Void
   let onShowAll: () -> Void
   let onShowStats: () -> Void
   let onSettings: () -> Void
   let authState: WatchAuthState
   let onProfile: () -> Void
   let finishingRows: [String: WatchToDoItem]
   let reopeningRows: [String: WatchToDoItem]
   @State private var selectedFilter: WatchToDoFilter = .recent
   @ScaledMetric(relativeTo: .headline) private var scaledActionHeight: CGFloat = 54

   private var actionHeight: CGFloat {
      min(max(scaledActionHeight, 50), 62)
   }

   private var activeItems: [WatchToDoItem] {
      let activeItems = store.toDoItems.map { reopeningRows[$0.id] ?? finishingRows[$0.id] ?? $0 }
      return Array(filteredItems(from: activeItems).prefix(3))
   }

   var body: some View {
	      ScrollView {
	         VStack(alignment: .leading, spacing: 10) {
            WatchRootHeader(
               toDoCount: store.toDoItems.count,
               authState: authState,
               onProfile: onProfile,
               onSettings: onSettings
            )

            WatchCard(spacing: 10) {
               Text("What matters now?")
                  .font(.watchBodyStrong(19, relativeTo: .headline))
                  .fontWeight(.black)
                  .foregroundStyle(WatchAppColor.textPrimary)

               Button(action: onCreate) {
                  HStack(spacing: 0) {
                     Image(systemName: "plus")
                        .font(.watchSymbol(17, weight: .bold))
                        .frame(width: 22, height: 22)

                     Text("New toDō")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                        .frame(maxWidth: .infinity)

                     Color.clear
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                  }
                  .frame(maxWidth: .infinity, alignment: .center)
                  .frame(maxWidth: .infinity)
               }
               .buttonStyle(WatchHomeActionButtonStyle(
                  foreground: WatchAppColor.onAction,
                  fill: WatchAppColor.actionPrimary,
                  pressedFill: WatchAppColor.secondary,
                  height: actionHeight
               ))

               Button(action: onShowAll) {
                  HStack(spacing: 0) {
                     Image(systemName: "checkmark")
                        .font(.watchSymbol(16, weight: .bold))
                        .frame(width: 22, height: 22)

                     Text("See all toDōs")
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                        .frame(maxWidth: .infinity)

                     Image(systemName: "arrow.right")
                        .font(.watchSymbol(16, weight: .bold))
                        .frame(width: 22, height: 22)
                  }
                  .frame(maxWidth: .infinity, alignment: .center)
                  .frame(maxWidth: .infinity)
               }
               .buttonStyle(WatchHomeActionButtonStyle(
                  foreground: WatchAppColor.secondary,
                  fill: WatchAppColor.secondary.opacity(0.13),
                  pressedFill: WatchAppColor.secondary.opacity(0.24),
                  height: actionHeight
               ))
            }

            if !store.toDoItems.isEmpty {
               VStack(alignment: .leading, spacing: 7) {
                  Text("Up next")
                     .font(.watchDisplay(20, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  ScrollView(.horizontal, showsIndicators: false) {
                     HStack(spacing: 6) {
                        ForEach(WatchToDoFilter.allCases) { filter in
                           Button {
                              withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                 selectedFilter = filter
                              }
                           } label: {
                              Text(filter.title)
                                 .font(.watchBodyStrong(10, relativeTo: .caption2))
                                 .padding(.horizontal, 9)
                                 .padding(.vertical, 6)
                                 .foregroundStyle(selectedFilter == filter ? WatchAppColor.onAction : filter.tint)
                                 .background(selectedFilter == filter ? filter.tint : WatchAppColor.surfaceElevated, in: Capsule())
                           }
                           .buttonStyle(.plain)
                        }
                     }
                  }

                  if activeItems.isEmpty {
                     Text("Nothing needs the front row right now.")
                        .font(.watchBody(12, relativeTo: .caption))
                        .foregroundStyle(WatchAppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                  } else {
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
         }
	         .padding(.horizontal, 6)
	         .padding(.bottom, 20)
	      }
	      .background(WatchAppColor.surface)
	      .accessibilityIdentifier("watch.home")
	   }

   private func filteredItems(from items: [WatchToDoItem]) -> [WatchToDoItem] {
      let now = Date()
      switch selectedFilter {
      case .recent:
         return items.sorted { $0.createdAt > $1.createdAt }
      case .dueSoon:
         return items
            .filter {
               guard let dueDate = $0.dueDate, !$0.isOverdue else { return false }
               return dueDate <= now.addingTimeInterval(3 * 24 * 60 * 60)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      case .timeSensitive:
         return items
            .filter(\.isTimeSensitive)
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      }
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
   @State private var selectedFilter: WatchToDoFilter = .recent
   @State private var isSearchVisible = false
   @State private var searchText = ""

   private var filteredItems: [WatchToDoItem] {
      let now = Date()
      switch selectedFilter {
      case .recent:
         return displayedItems.sorted { $0.createdAt > $1.createdAt }
      case .dueSoon:
         return displayedItems
            .filter {
               guard let dueDate = $0.dueDate, !$0.isOverdue else { return false }
               return dueDate <= now.addingTimeInterval(3 * 24 * 60 * 60)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      case .timeSensitive:
         return displayedItems
            .filter(\.isTimeSensitive)
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
      }
   }

   private var visibleItems: [WatchToDoItem] {
      let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !query.isEmpty else { return filteredItems }
      return filteredItems.filter { item in
         item.task.localizedStandardContains(query)
            || item.tags.contains { $0.name.localizedStandardContains(query) }
            || item.nanoDos.contains { $0.task.localizedStandardContains(query) }
      }
   }

   private var overdueCount: Int {
      visibleItems.filter(\.isOverdue).count
   }

   var body: some View {
	      ScrollView {
	         VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
               HStack(alignment: .center, spacing: 2) {
                  Text("toD\(Text("ō").foregroundStyle(WatchAppColor.main))")
                     .font(.watchBrand(28, relativeTo: .title2))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  ToDoBrandPlusMark(
                     font: .watchBrand(20, relativeTo: .title3),
                     width: 16,
                     height: 20
                  )
               }

               Spacer(minLength: 0)

               Button {
                  withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                     isSearchVisible.toggle()
                     if !isSearchVisible { searchText = "" }
                  }
               } label: {
                  Image(systemName: isSearchVisible ? "xmark" : "magnifyingglass")
                     .font(.watchSymbol(13, weight: .black))
                     .frame(width: 30, height: 30)
               }
               .buttonStyle(WatchCircleButtonStyle())
               .accessibilityLabel(isSearchVisible ? "Close search" : "Search toDōs")
            }

            if isSearchVisible {
               TextField("Search toDōs", text: $searchText)
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .textInputAutocapitalization(.never)
                  .transition(.move(edge: .top).combined(with: .opacity))
            }

            Button(action: onCreate) {
               Label("New toDō", systemImage: "plus")
                  .font(.watchButton(20, relativeTo: .title3))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchProminentButtonStyle())

            ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 6) {
                  ForEach(WatchToDoFilter.allCases) { filter in
                     Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                           selectedFilter = filter
                        }
                     } label: {
                        Text(filter.title)
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .padding(.horizontal, 9)
                           .padding(.vertical, 6)
                           .foregroundStyle(selectedFilter == filter ? WatchAppColor.onAction : filter.tint)
                           .background(selectedFilter == filter ? filter.tint : WatchAppColor.surfaceElevated, in: Capsule())
                     }
                     .buttonStyle(.plain)
                  }
               }
            }

            if visibleItems.isEmpty {
               WatchEmptyToDoState()
            } else {
               VStack(alignment: .leading, spacing: 6) {
                  ForEach(visibleItems) { item in
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
               Image(systemName: "arrow.clockwise")
                  .font(.watchSymbol(24, weight: .bold))
                  .foregroundStyle(WatchAppColor.main)
                  .frame(maxWidth: .infinity)
                  .padding(.top, 18)
                  .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            Text(summaryText)
               .font(.watchBodyStrong(10, relativeTo: .caption2))
               .foregroundStyle(overdueCount > 0 ? WatchAppColor.destructive : WatchAppColor.textSecondaryStrong)
               .frame(maxWidth: .infinity, alignment: .center)
               .multilineTextAlignment(.center)
         }
         .padding(.horizontal, 6)
	         .padding(.bottom, 20)
	      }
	      .background(WatchAppColor.surface)
	      .accessibilityIdentifier("watch.todos")
	   }

   private var summaryText: String {
      let visible = WatchLocalization.localizedCount(visibleItems.count, singularKey: "%@ toDō", pluralKey: "%@ toDōs")
      if overdueCount > 0 {
         let overdue = WatchLocalization.localizedCount(overdueCount, singularKey: "%@ overdue", pluralKey: "%@ overdue")
         return "\(visible) · \(overdue) · \(lastUpdatedLabel)"
      }
      return "\(visible) · \(lastUpdatedLabel)"
   }
}

private struct WatchRootHeader: View {
   let toDoCount: Int
   let authState: WatchAuthState
   let onProfile: () -> Void
   let onSettings: () -> Void

   var body: some View {
      HStack(alignment: .center, spacing: 10) {
         VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 2) {
               Text("toD\(Text("ō").foregroundStyle(WatchAppColor.main))")
                  .font(.watchBrand(28, relativeTo: .title2))
                  .foregroundStyle(WatchAppColor.textPrimary)

               ToDoBrandPlusMark(
                  font: .watchBrand(20, relativeTo: .title3),
                  width: 16,
                  height: 20
               )
            }

            Text(WatchLocalization.localizedCount(toDoCount, singularKey: "%@ toDō", pluralKey: "%@ toDōs"))
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
         }
         .accessibilityElement(children: .combine)

         Spacer(minLength: 0)

         VStack(spacing: 6) {
            if authState.isAuthenticated {
               Button(action: onProfile) {
                  WatchProfileAvatar(authState: authState)
               }
               .buttonStyle(.plain)
               .accessibilityLabel("Open My Profile")
               .accessibilityHint("Shows your account profile.")
            }

            Button(action: onSettings) {
               Image(systemName: "gearshape.fill")
                  .font(.watchDisplay(19, relativeTo: .headline))
                  .frame(width: 34, height: 34)
            }
            .buttonStyle(WatchCircleButtonStyle())
            .accessibilityLabel("Open settings")
         }
      }
   }
}

private struct WatchProfileView: View {
   @Environment(\.dismiss) private var dismiss
   @ObservedObject var authStore: WatchAuthStore
   @ObservedObject var store: WatchToDoStore
   @State private var isShowingDeleteAccountConfirmation = false
   @State private var isDeletingAccount = false
   @State private var accountDeletionError: String?

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "My Profile",
               systemImage: "person.crop.circle.fill",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard(spacing: 10) {
               HStack(spacing: 10) {
                  WatchProfileAvatar(authState: authStore.authState)
                     .frame(width: 52, height: 52)

                  VStack(alignment: .leading, spacing: 2) {
                     Text(displayName)
                        .font(.watchBodyStrong(16, relativeTo: .headline))
                        .foregroundStyle(WatchAppColor.textPrimary)
                        .lineLimit(2)

                     Text(authStore.authState.isAuthenticated ? "toDō account" : "Not connected")
                        .font(.watchBodyStrong(11, relativeTo: .caption))
                        .foregroundStyle(WatchAppColor.textSecondary)
                  }
               }

               if let email = authStore.authState.email, !email.isEmpty {
                  WatchMetadataRow(
                     systemImage: "envelope.fill",
                     title: "Email",
                     value: email,
                     accent: WatchAppColor.actionPrimary
                  )
               }

               if let provider = authStore.authState.provider, !provider.isEmpty {
                  WatchMetadataRow(
                     systemImage: "person.crop.circle.badge.checkmark",
                     title: "Sign-in Method",
                     value: provider,
                     accent: WatchAppColor.actionSuccess
                  )
               }
            }

            if authStore.authState.isAuthenticated {
               WatchCard(spacing: 8) {
                  if authStore.standaloneSession != nil {
                     Button(role: .destructive) {
                        isShowingDeleteAccountConfirmation = true
                     } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.destructive))
                     .disabled(isDeletingAccount)
                     .accessibilityHint("Permanently deletes your account and account data.")
                  } else {
                     Text("Delete this account from the iPhone app.")
                        .font(.watchBody(10, relativeTo: .caption2))
                        .foregroundStyle(WatchAppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                  }
               }
            }
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .background(WatchAppColor.surface)
      .toolbarBackground(.hidden, for: .navigationBar)
      .alert("Delete Account", isPresented: $isShowingDeleteAccountConfirmation) {
         Button("Delete Account", role: .destructive) {
            deleteAccount()
         }
         Button("Cancel", role: .cancel) {}
      } message: {
         Text("This permanently deletes your toDōs, profile, shared lists, and account. This cannot be undone.")
      }
      .alert("Account Deletion Failed", isPresented: Binding(
         get: { accountDeletionError != nil },
         set: { if !$0 { accountDeletionError = nil } }
      )) {
         Button("OK", role: .cancel) {}
      } message: {
         Text(accountDeletionError ?? "Try again when you have a reliable connection.")
      }
      .toolbar {
         ToolbarItem(placement: .topBarTrailing) {
            Button {
               dismiss()
            } label: {
               Image(systemName: "xmark")
            }
            .accessibilityLabel("Close Profile")
         }
      }
   }

   private var displayName: String {
      let value = authStore.authState.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let value, !value.isEmpty { return value }
      if let email = authStore.authState.email,
         let localPart = email.split(separator: "@").first,
         !localPart.isEmpty {
         return String(localPart)
      }
      return String(localized: "toDō User")
   }

   private func deleteAccount() {
      isDeletingAccount = true
      Task { @MainActor in
         defer { isDeletingAccount = false }
         do {
            try await authStore.deleteAccount()
            store.clearAllForAccountDeletion()
            dismiss()
         } catch {
            accountDeletionError = error.localizedDescription
         }
      }
   }
}

private struct WatchProfileAvatar: View {
   let authState: WatchAuthState

   var body: some View {
      Group {
         if let avatarURL = authState.avatarURL,
            let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
               if case .success(let image) = phase {
                  image.resizable().scaledToFill()
               } else {
                  initialsView
               }
            }
         } else {
            initialsView
         }
      }
      .frame(width: 34, height: 34)
      .clipShape(Circle())
      .overlay(Circle().stroke(WatchAppColor.actionPrimary, lineWidth: 2))
      .accessibilityHidden(true)
   }

   private var initialsView: some View {
      ZStack {
         Circle().fill(WatchAppColor.actionPrimary.opacity(0.18))
         Text(initials)
            .font(.watchBodyStrong(11, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.actionPrimary)
            .minimumScaleFactor(0.7)
      }
   }

   private var initials: String {
      let source = authState.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
         ?? authState.email?.trimmingCharacters(in: .whitespacesAndNewlines)
         ?? String(localized: "toDō User")
      let words = source.split(whereSeparator: { $0 == " " || $0 == "-" })
      if let first = words.first, let last = words.dropFirst().first {
         return (String(first.prefix(1)) + String(last.prefix(1))).uppercased()
      }
      return String(source.prefix(2)).uppercased()
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
   @State private var selectedStatsPage = 0

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

            WatchActivityGraph(items: snapshot.activityItems)
               .padding(.horizontal, 6)

            TabView(selection: $selectedStatsPage) {
               WatchStatsPage(
                  title: "Momentum",
                  systemImage: "chart.bar.xaxis",
                  accent: WatchAppColor.actionSuccess,
                  items: [
                     WatchMetricItem(title: "Active", value: snapshot.active, systemImage: "bolt.fill", tint: WatchAppColor.secondary),
                     WatchMetricItem(title: "Done", value: snapshot.done, systemImage: "checkmark.circle.fill", tint: WatchAppColor.actionSuccess)
                  ]
               )
               .tag(0)

               WatchStatsPage(
                  title: "Workload Shape",
                  systemImage: "calendar",
                  accent: WatchAppColor.main,
                  items: [
                     WatchMetricItem(title: "Due today", value: snapshot.dueToday, systemImage: "calendar", tint: WatchAppColor.main),
                     WatchMetricItem(title: "Due soon", value: snapshot.dueSoon, systemImage: "clock.fill", tint: WatchAppColor.main)
                  ]
               )
               .tag(1)

               WatchStatsPage(
                  title: "Organization",
                  systemImage: "list.bullet.rectangle",
                  accent: WatchAppColor.secondary,
                  items: [
                     WatchMetricItem(title: "Scheduled", value: snapshot.scheduled, systemImage: "calendar.badge.clock", tint: WatchAppColor.main),
                     WatchMetricItem(title: "Recurring", value: snapshot.recurring, systemImage: "repeat", tint: WatchAppColor.secondary)
                  ]
               )
               .tag(2)

               WatchStatsPage(
                  title: "Completion Trends",
                  systemImage: "checkmark.circle.fill",
                  accent: WatchAppColor.actionSuccess,
                  items: [
                     WatchMetricItem(title: "Done", value: snapshot.done, systemImage: "checkmark.circle.fill", tint: WatchAppColor.actionSuccess),
                     WatchMetricItem(title: "NanoDos", value: snapshot.nanoDos, systemImage: "smallcircle.filled.circle", tint: WatchAppColor.main)
                  ]
               )
               .tag(3)

               WatchStatsPage(
                  title: "Planning Accuracy",
                  systemImage: "target",
                  accent: WatchAppColor.secondary,
                  items: [
                     WatchMetricItem(title: "Tags", value: snapshot.tagged, systemImage: "tag.fill", tint: WatchAppColor.secondary),
                     WatchMetricItem(title: "Notes", value: snapshot.noted, systemImage: "note.text", tint: WatchAppColor.textSecondary)
                  ]
               )
               .tag(4)

               WatchStatsPage(
                  title: "Pressure Signals",
                  systemImage: "exclamationmark.circle.fill",
                  accent: WatchAppColor.destructive,
                  items: [
                     WatchMetricItem(title: "Overdue", value: snapshot.overdue, systemImage: "exclamationmark.circle.fill", tint: WatchAppColor.destructive),
                     WatchMetricItem(title: "Time-sensitive", value: snapshot.timeSensitive, systemImage: "flame.fill", tint: WatchAppColor.destructive)
                  ]
               )
               .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 148)

            HStack(spacing: 5) {
               ForEach(0..<6, id: \.self) { index in
                  Capsule(style: .continuous)
                     .fill(index == selectedStatsPage ? WatchAppColor.actionPrimary : WatchAppColor.surfaceMuted)
                     .frame(width: index == selectedStatsPage ? 18 : 6, height: 5)
                     .accessibilityHidden(true)
               }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Stats section \(selectedStatsPage + 1) of 6")
         }
         .padding(.horizontal, 6)
         .padding(.bottom, 20)
      }
      .background(WatchAppColor.surface)
      .accessibilityIdentifier("watch.stats")
   }
}

private struct WatchStatsPage: View {
   let title: LocalizedStringKey
   let systemImage: String
   let accent: Color
   let items: [WatchMetricItem]

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Label(title, systemImage: systemImage)
            .font(.watchViewTitle(18, relativeTo: .headline))
            .foregroundStyle(accent)
            .padding(.horizontal, 4)

         WatchMetricGrid(items: items)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

private struct WatchStatsSnapshot {
   let activityItems: [WatchToDoItem]
   let active: Int
   let done: Int
   let overdue: Int
   let dueToday: Int
   let dueSoon: Int
   let timeSensitive: Int
   let scheduled: Int
   let recurring: Int
   let nanoDos: Int
   let tagged: Int
   let noted: Int
   let locationReminders: Int

   init(store: WatchToDoStore, now: Date = .now) {
      let activeItems = store.toDoItems
      activityItems = store.toDoItems + store.doneItems
      active = activeItems.count
      done = store.doneItems.count
      overdue = activeItems.filter(\.isOverdue).count
      dueToday = activeItems.filter { item in
         guard let dueDate = item.dueDate else { return false }
         return Calendar.current.isDateInToday(dueDate)
      }.count
      dueSoon = activeItems.filter { item in
         guard !item.isOverdue, let dueDate = item.dueDate else { return false }
         return dueDate <= now.addingTimeInterval(3 * 24 * 60 * 60)
      }.count
      timeSensitive = activeItems.filter(\.isTimeSensitive).count
      scheduled = activeItems.filter { $0.dueDate != nil }.count
      recurring = activeItems.filter { $0.recurrenceSummary != nil }.count
      nanoDos = activeItems.reduce(0) { $0 + $1.nanoDos.count }
      tagged = activeItems.filter { !$0.tags.isEmpty }.count
      noted = activeItems.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
      locationReminders = activeItems.filter(\.hasLocationReminder).count
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
         WatchMetricItem(title: "Due today", value: dueToday, systemImage: "calendar", tint: WatchAppColor.main),
         WatchMetricItem(title: "Overdue", value: overdue, systemImage: "exclamationmark.circle.fill", tint: WatchAppColor.destructive),
         WatchMetricItem(title: "Time-sensitive", value: timeSensitive, systemImage: "flame.fill", tint: WatchAppColor.destructive)
      ]
   }
}

private struct WatchActivityDay: Identifiable {
   let date: Date
   let completionCount: Int
   var id: Date { date }

   var intensity: Int {
      switch completionCount {
      case 0: return 0
      case 1: return 1
      case 2: return 2
      case 3...4: return 3
      default: return 4
      }
   }
}

private enum WatchActivityTracker {
   static func grid(from items: [WatchToDoItem], endingAt endDate: Date = .now, weekCount: Int = 8) -> [[WatchActivityDay]] {
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: endDate)
      let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
      let firstWeek = calendar.date(byAdding: .weekOfYear, value: -(max(1, weekCount) - 1), to: weekStart) ?? weekStart
      let counts = Dictionary(grouping: items.compactMap { item -> Date? in
         guard item.isDone else { return nil }
         return calendar.startOfDay(for: item.completedAt ?? item.updatedAt)
      }, by: { $0 }).mapValues { $0.count }

      return (0..<max(1, weekCount)).map { week in
         (0..<7).map { day in
            let date = calendar.date(byAdding: .day, value: week * 7 + day, to: firstWeek) ?? firstWeek
            return WatchActivityDay(date: date, completionCount: counts[date, default: 0])
         }
      }
   }
}

private struct WatchActivityGraph: View {
   @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
   let items: [WatchToDoItem]

   private var weeks: [[WatchActivityDay]] {
      WatchActivityTracker.grid(from: items)
   }

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 4) {
               ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                  VStack(spacing: 4) {
                     ForEach(week) { day in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                           .fill(cellColor(for: day))
                           .frame(width: 7, height: 7)
                           .overlay {
                              if differentiateWithoutColor {
                                 RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .stroke(WatchAppColor.textPrimary.opacity(day.completionCount == 0 ? 0.2 : 0.7), lineWidth: 0.7)
                              }
                           }
                           .accessibilityLabel("\(day.completionCount) completed")
                     }
                  }
               }
            }
            .frame(maxWidth: .infinity, alignment: .center)
         }
         .frame(height: 73)

         HStack(spacing: 4) {
            Text("Less")
            ForEach(0..<5, id: \.self) { level in
               RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                  .fill(cellColor(for: WatchActivityDay(date: .now, completionCount: level)))
                  .frame(width: 6, height: 6)
            }
            Text("More")
         }
         .font(.watchBody(9, relativeTo: .caption2))
         .foregroundStyle(WatchAppColor.textSecondary.opacity(0.72))
         .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.vertical, 4)
   }

   private func cellColor(for day: WatchActivityDay) -> Color {
      switch day.intensity {
      case 0: return WatchAppColor.surfaceElevated.opacity(0.8)
      case 1: return WatchAppColor.secondary.opacity(0.3)
      case 2: return WatchAppColor.secondary.opacity(0.5)
      case 3: return WatchAppColor.secondary.opacity(0.72)
      default: return WatchAppColor.secondary
      }
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
   @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

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
                     .font(.watchSymbol(12, weight: .black))
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
            .overlay {
               if differentiateWithoutColor {
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                     .strokeBorder(
                        WatchAppColor.textPrimary.opacity(0.78),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                     )
               }
            }
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
            .font(.watchSymbol(12, weight: .black))
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
   case profile
   case migrationReview
   case doneToDos
   case stats
}
