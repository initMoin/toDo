import Combine
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
   static let shared = NotificationManager()

   enum RemoteNotificationHandlingResult {
      case noData
      case newData
      case failed
   }

   enum RegistrationState: Equatable {
      case idle
      case requesting
      case registered(token: String)
      case failed(String)

      var statusText: String {
         switch self {
         case .idle:
            return "Not registered"
         case .requesting:
            return "Registering"
         case .registered:
            return "Push ready"
         case .failed:
            return "Push unavailable"
         }
      }
   }

   var pushReadinessDetail: String {
      switch registrationState {
      case .idle:
         return "This device has not registered an APNs token yet."
      case .requesting:
         return "ToDo is asking iOS for an APNs device token."
      case .registered(let token):
         return "APNs token registered. Token ends in \(token.suffix(8))."
      case .failed(let message):
         return "APNs registration failed. \(message)"
      }
   }

   @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
   @Published private(set) var timeSensitiveSetting: UNNotificationSetting = .notSupported
   @Published private(set) var registrationState: RegistrationState = .idle

   @Published private(set) var currentAPNSToken: String?

   private let center = UNUserNotificationCenter.current()
   private let notificationPrefix = "todo.due."
   private let categoryIdentifier = "TODO_DUE_REMINDER"
   private let markDoneActionIdentifier = "todo.markDone"
   private let snoozeActionPrefix = "todo.snooze."
   private let initialSyncDelayNanoseconds: UInt64 = 1_500_000_000
   private let coalescedSyncDelayNanoseconds: UInt64 = 350_000_000
   private let maxScheduledNotificationRequests = 64

   private var modelContainer: ModelContainer?
   private var remoteNotificationRegistrar: (@MainActor () -> Void)?
   private var scheduledSyncTask: Task<Void, Never>?
   private var isSyncingScheduledNotifications = false
   private var needsScheduledNotificationSyncAfterCurrent = false

   private override init() {
      super.init()
      if let token = UserDefaults.standard.string(forKey: AppPreferences.Keys.remotePushDeviceToken),
         !token.isEmpty {
         registrationState = .registered(token: token)
      }
   }

   func configure(
      modelContainer: ModelContainer,
      remoteNotificationRegistrar: (@MainActor () -> Void)? = nil
   ) {
      self.modelContainer = modelContainer
      self.remoteNotificationRegistrar = remoteNotificationRegistrar
      center.delegate = self
      registerNotificationCategories()

      Task {
         await refreshAuthorizationStatus()
         scheduleRefresh(delayNanoseconds: initialSyncDelayNanoseconds)
      }
   }

   func refreshAuthorizationStatus() async {
      let settings = await center.notificationSettings()
      authorizationStatus = settings.authorizationStatus
      timeSensitiveSetting = settings.timeSensitiveSetting
   }

   func requestAuthorizationFlow() async {
      registerNotificationCategories()

      do {
         let granted = try await center.requestAuthorization(
            options: [.alert, .badge, .sound]
         )
         await refreshAuthorizationStatus()

         guard granted else { return }

         registerNotificationCategories()
         registerForRemoteNotifications()
         await syncScheduledNotifications()
      } catch {
         registrationState = .failed(error.localizedDescription)
         await refreshAuthorizationStatus()
      }
   }

   func registerForRemoteNotifications() {
      guard authorizationStatus == .authorized
               || authorizationStatus == .provisional
               || authorizationStatus == .ephemeral else {
         return
      }

      registrationState = .requesting
      remoteNotificationRegistrar?()
   }

   func didRegisterForRemoteNotifications(deviceToken: Data) {
      let token = deviceToken.map { String(format: "%02x", $0) }.joined()
      registrationState = .registered(token: token)

      let previousToken = UserDefaults.standard.string(
         forKey: AppPreferences.Keys.remotePushDeviceToken
      )

      guard previousToken != token else {
         registrationState = .registered(token: token)
         currentAPNSToken = token
         return
      }

      UserDefaults.standard.set(
         token,
         forKey: AppPreferences.Keys.remotePushDeviceToken
      )

      registrationState = .registered(token: token)
      currentAPNSToken = token

      #if DEBUG
      AppLog.info("APNs token updated. Token ends in \(token.suffix(8)).", logger: AppLog.notifications)
      #endif

      Task {
         await SupabaseAuthStore.shared.syncCurrentDeviceTokenIfPossible()
      }
   }

   func didFailToRegisterForRemoteNotifications(error: Error) {
      registrationState = .failed(error.localizedDescription)
   }

   func scheduleRefresh() {
      scheduleRefresh(delayNanoseconds: coalescedSyncDelayNanoseconds)
   }

   private func scheduleRefresh(delayNanoseconds: UInt64) {
      scheduledSyncTask?.cancel()
      scheduledSyncTask = Task { [weak self] in
         guard let self else { return }

         if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
         }

         guard !Task.isCancelled else { return }
         await self.syncScheduledNotifications()
      }
   }

   func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> RemoteNotificationHandlingResult {
      if isRemoteSyncRefreshPayload(userInfo) {
         guard let userID = SupabaseAuthStore.shared.currentUserID else {
            return .noData
         }

         await SyncCoordinator.shared.refreshFromRemote(userID: userID)
         await syncScheduledNotifications()
         return .newData
      }

      guard let action = userInfo["todoAction"] as? String,
            let container = modelContainer else {
         return .noData
      }

      let toDoIdentifier = userInfo["todoIdentifier"] as? String
      let toDoCloudIdentifier = (userInfo["todoCloudIdentifier"] as? String).flatMap(UUID.init(uuidString:))

      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         guard let toDo = toDo(
            matchingLocalIdentifier: toDoIdentifier,
            cloudIdentifier: toDoCloudIdentifier,
            in: toDos
         ) else {
            return .noData
         }

         switch action {
         case "markDone":
            toDo.transition(to: .done)
         case "archive":
            toDo.transition(to: .archived)
         case "delete":
            SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(for: toDo, in: context)
            context.delete(toDo)
         default:
            return .noData
         }

         try context.save()
         await MainActor.run {
            SyncCoordinator.shared.scheduleLocalSync()
         }
         await syncScheduledNotifications()
         return .newData
      } catch {
         return .failed
      }
   }

   private func isRemoteSyncRefreshPayload(_ userInfo: [AnyHashable: Any]) -> Bool {
      let candidates = [
         userInfo["todoSync"] as? String,
         userInfo["todo_sync_event"] as? String,
         userInfo["syncEvent"] as? String
      ]

      if candidates.contains(where: { value in
         guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !normalized.isEmpty else {
            return false
         }
         return normalized == "refresh" || normalized == "changed" || normalized == "pull"
      }) {
         return true
      }

      if let typeRaw = userInfo["type"] as? String,
         let type = RemoteNotificationType(rawValue: typeRaw) {
         return type == .syncCompleted || type == .syncConflict
      }

      return false
   }

   func syncScheduledNotifications() async {
      guard let container = modelContainer else { return }
      guard !isSyncingScheduledNotifications else {
         needsScheduledNotificationSyncAfterCurrent = true
         return
      }

      isSyncingScheduledNotifications = true
      defer {
         isSyncingScheduledNotifications = false
         if needsScheduledNotificationSyncAfterCurrent {
            needsScheduledNotificationSyncAfterCurrent = false
            scheduleRefresh()
         }
      }

      registerNotificationCategories()

      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         let now = Date()
         let schedulableOccurrences = limitedScheduledOccurrences(for: toDos, now: now)
         await updateAppIconBadge(for: toDos, now: now)

         let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(notificationPrefix) }
         let deliveredIdentifiers = await center.deliveredNotifications()
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(notificationPrefix) }
         let existingIdentifiers = Array(Set(pendingIdentifiers + deliveredIdentifiers))

         if !existingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)
            center.removeDeliveredNotifications(withIdentifiers: existingIdentifiers)
         }

         for occurrence in schedulableOccurrences {
            let notificationType = notificationType(
               for: occurrence.toDo,
               fireDate: occurrence.fireDate
            )
            let resolvedInterruptionLevel = interruptionLevel(for: occurrence.toDo)
            let isTimeSensitive = resolvedInterruptionLevel == .timeSensitive
            let content = NotificationContentBuilder.content(
               for: notificationType,
               title: notificationTitle(for: occurrence.toDo, fireDate: occurrence.fireDate),
               body: notificationBody(for: occurrence.toDo),
	               isTimeSensitive: isTimeSensitive,
	               isQuiet: occurrence.toDo.reminderIntent == .soft,
	               soundOption: preferredSoundOption
	            )
            content.badge = NSNumber(value: appIconBadgeCount(for: toDos, now: occurrence.fireDate))

            var userInfo: [String: Any] = [
               "schemaVersion": 1,
               "type": notificationType.rawValue,
               "todoIdentifier": persistentIdentifierString(for: occurrence.toDo),
               "isRecurring": occurrence.toDo.isRecurring,
               "isTimeSensitive": isTimeSensitive,
               "occurrenceIndex": occurrence.occurrenceIndex
            ]

            if let cloudID = occurrence.toDo.cloudID {
               userInfo["todoCloudIdentifier"] = cloudID.uuidString
            }

            content.userInfo = userInfo

            let triggerDate = Calendar.current.dateComponents(
               [.year, .month, .day, .hour, .minute, .second],
               from: occurrence.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
               identifier: notificationIdentifier(for: occurrence.toDo, occurrenceIndex: occurrence.occurrenceIndex, fireDate: occurrence.fireDate),
               content: content,
               trigger: trigger
            )

            try await center.add(request)
         }
      } catch {
         AppLog.error("Failed to sync notifications: \(error)", logger: AppLog.notifications)
      }
   }

   private func registerNotificationCategories() {
      let legacyCategory = UNNotificationCategory(
         identifier: categoryIdentifier,
         actions: [markDoneAction()] + snoozeActions(),
         intentIdentifiers: [],
         options: [.customDismissAction]
      )
      let taskReminderCategory = UNNotificationCategory(
         identifier: NotificationCategoryID.taskReminder.rawValue,
         actions: [markDoneAction()] + snoozeActions(),
         intentIdentifiers: [],
         options: [.customDismissAction]
      )
      let recurringReminderCategory = UNNotificationCategory(
         identifier: NotificationCategoryID.recurringReminder.rawValue,
         actions: [markDoneAction()] + snoozeActions(),
         intentIdentifiers: [],
         options: [.customDismissAction]
      )
      let syncCategory = UNNotificationCategory(
         identifier: NotificationCategoryID.sync.rawValue,
         actions: [],
         intentIdentifiers: [],
         options: []
      )

      center.setNotificationCategories([
         legacyCategory,
         taskReminderCategory,
         recurringReminderCategory,
         syncCategory
      ])
   }

   private func markDoneAction() -> UNNotificationAction {
      UNNotificationAction(
         identifier: markDoneActionIdentifier,
         title: "Mark Done",
         options: []
      )
   }

   private func snoozeActions() -> [UNNotificationAction] {
      currentSnoozeDescriptors().map { descriptor in
         UNNotificationAction(
            identifier: snoozeActionPrefix + descriptor.identifier,
            title: descriptor.title,
            options: []
         )
      }
   }

   private func currentSnoozeDescriptors() -> [SnoozeDescriptor] {
      let store = SnoozePreferences.decode(
         UserDefaults.standard.string(forKey: SnoozePreferences.storageKey)
         ?? SnoozePreferences.defaultEncodedString
      )

      var descriptors: [SnoozeDescriptor] = []

      if let minutes = store.minutes.first {
         descriptors.append(.init(unit: .minutes, value: minutes))
      }

      if let hours = store.hours.first {
         descriptors.append(.init(unit: .hours, value: hours))
      }

      if let days = store.days.first {
         descriptors.append(.init(unit: .days, value: days))
      }

      return Array(descriptors.prefix(3))
   }

   private func notificationIdentifier(for toDo: ToDo, occurrenceIndex: Int, fireDate: Date) -> String {
      notificationPrefix + persistentIdentifierString(for: toDo) + ".\(occurrenceIndex).\(Int(fireDate.timeIntervalSince1970))"
   }

   private func notificationTitle(for toDo: ToDo, fireDate: Date) -> String {
      guard toDo.dueDate != nil else {
         return "ToDo reminder"
      }

      if fireDate < .now {
         return "ToDo: overdue"
      }

      if toDo.isRecurring {
         return "ToDo: repeating"
      }

      switch toDo.reminderIntent {
      case .soft:
         return "ToDo reminder"
      case .due, .timeSensitive:
         return "ToDo: due"
      }
   }

   private func notificationBody(for toDo: ToDo) -> String {
      let task = toDo.task.trimmingCharacters(in: .whitespacesAndNewlines)
      return task.isEmpty ? "Open ToDo to review this reminder." : task
   }

   private func interruptionLevel(for toDo: ToDo) -> UNNotificationInterruptionLevel {
      switch toDo.reminderIntent {
      case .soft:
         return .passive
      case .due:
         return .active
      case .timeSensitive:
         return timeSensitiveSetting == .enabled
            ? .timeSensitive
            : .active
      }
   }

   private func notificationType(for toDo: ToDo, fireDate: Date) -> RemoteNotificationType {
      if fireDate < .now {
         return .toDoOverdue
      }

      if toDo.isRecurring {
         return .recurringToDo
      }

      return toDo.reminderIntent == .soft ? .reminder : .toDoDue
   }

   private func persistentIdentifierString(for toDo: ToDo) -> String {
      String(describing: toDo.id)
   }

   private var preferredSoundOption: AppPreferences.NotificationSoundOption {
      let rawValue = UserDefaults.standard.string(forKey: AppPreferences.Keys.notificationSoundOption)
      return rawValue.flatMap(AppPreferences.NotificationSoundOption.init(rawValue:)) ?? .defaultSound
   }

   private func notificationSound(for option: AppPreferences.NotificationSoundOption) -> UNNotificationSound? {
      guard option != .silent else { return nil }

      if let bundledSoundName = option.bundledSoundName {
         return UNNotificationSound(named: UNNotificationSoundName(rawValue: bundledSoundName))
      }

      return .default
   }

   #if DEBUG
   func scheduleDebugNotification(
      scenario: NotificationDebugScenario,
      toDo: ToDo?,
      after seconds: TimeInterval = 5
   ) async throws {
      let toDoTitle = toDo?.task.trimmingCharacters(in: .whitespacesAndNewlines)
      let content = NotificationContentBuilder.debugContent(
         for: scenario,
         toDoTitle: toDoTitle?.isEmpty == false ? toDoTitle! : "Review ToDo",
	         toDoIdentifier: toDo.map(persistentIdentifierString(for:)),
	         toDoCloudIdentifier: toDo?.cloudID
	      )
	      content.sound = notificationSound(for: preferredSoundOption)

	      let trigger = UNTimeIntervalNotificationTrigger(
         timeInterval: max(seconds, 1),
         repeats: false
      )
      let request = UNNotificationRequest(
         identifier: "todo.debug.\(scenario.rawValue).\(UUID().uuidString)",
         content: content,
         trigger: trigger
      )

      try await center.add(request)
   }

   func clearDebugNotifications() async {
      let pendingIdentifiers = await center.pendingNotificationRequests()
         .map(\.identifier)
         .filter { $0.hasPrefix("todo.debug.") }
      let deliveredIdentifiers = await center.deliveredNotifications()
         .map { $0.request.identifier }
         .filter { $0.hasPrefix("todo.debug.") }

      center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
      center.removeDeliveredNotifications(withIdentifiers: deliveredIdentifiers)
   }
   #endif

   private func scheduledNotificationOccurrences(for toDo: ToDo, now: Date, limit: Int = 24) -> [(fireDate: Date, occurrenceIndex: Int)] {
      guard let dueDate = toDo.dueDate else { return [] }

      guard toDo.isRecurring,
            let unit = toDo.recurrenceUnit,
            let interval = toDo.recurrenceInterval,
            interval > 0,
            let mode = toDo.recurrenceMode
      else {
         return dueDate > now ? [(fireDate: dueDate, occurrenceIndex: 0)] : []
      }

      let anchor = toDo.recurrenceAnchorDate ?? dueDate
      let totalOccurrences: Int? = mode == .finite ? max((toDo.recurrenceCount ?? 1) + 1, 1) : nil
      let startIndex = nextOccurrenceIndex(after: now, anchor: anchor, unit: unit, interval: interval)

      var occurrences: [(fireDate: Date, occurrenceIndex: Int)] = []
      var index = startIndex

      while occurrences.count < limit {
         if let totalOccurrences, index >= totalOccurrences {
            break
         }

         guard let fireDate = recurrenceDate(anchor: anchor, unit: unit, interval: interval, occurrenceIndex: index) else {
            break
         }

         if let endDate = toDo.recurrenceEndDate, fireDate > endDate {
            break
         }

         if fireDate > now {
            occurrences.append((fireDate: fireDate, occurrenceIndex: index))
         }

         index += 1
      }

      return occurrences
   }

   private func limitedScheduledOccurrences(for toDos: [ToDo], now: Date) -> [ScheduledOccurrence] {
      var occurrences: [ScheduledOccurrence] = []
      occurrences.reserveCapacity(maxScheduledNotificationRequests)

      let focusFilterMode = UserDefaults.standard.string(forKey: AppPreferences.Keys.toDoFocusFilterMode) ?? "all"

      for toDo in toDos where toDo.isActive && toDo.matchesFocusFilter(modeRawValue: focusFilterMode) {
         for occurrence in scheduledNotificationOccurrences(for: toDo, now: now) {
            occurrences.append(ScheduledOccurrence(
               toDo: toDo,
               fireDate: occurrence.fireDate,
               occurrenceIndex: occurrence.occurrenceIndex
            ))
         }

         if occurrences.count > maxScheduledNotificationRequests * 2 {
            occurrences.sort { $0.fireDate < $1.fireDate }
            occurrences = Array(occurrences.prefix(maxScheduledNotificationRequests))
         }
      }

      occurrences.sort { $0.fireDate < $1.fireDate }
      return Array(occurrences.prefix(maxScheduledNotificationRequests))
   }

   private func updateAppIconBadge(for toDos: [ToDo], now: Date) async {
      await withCheckedContinuation { continuation in
         center.setBadgeCount(appIconBadgeCount(for: toDos, now: now)) { _ in
            continuation.resume()
         }
      }
   }

   private func appIconBadgeCount(for toDos: [ToDo], now: Date) -> Int {
      let policy = AppPreferences.AppIconBadgePolicy(
         rawValue: UserDefaults.standard.string(forKey: AppPreferences.Keys.appIconBadgePolicy) ?? ""
      ) ?? .overdue

      guard policy != .off else { return 0 }

      let calendar = Calendar.current
      let activeToDos = toDos.filter(\.isActive)

      switch policy {
      case .off:
         return 0
      case .activeToDos:
         return activeToDos.count
      case .dueToday:
         return activeToDos.filter { toDo in
            toDo.dueDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false
         }.count
      case .overdue:
         return activeToDos.filter { toDo in
            toDo.dueDate.map { $0 < now } ?? false
         }.count
      case .timeSensitive:
         return activeToDos.filter { $0.reminderIntent == .timeSensitive }.count
      case .scheduledReminders:
         return activeToDos.filter { toDo in
            scheduledNotificationOccurrences(for: toDo, now: now, limit: 1).isEmpty == false
         }.count
      }
   }

   private func nextOccurrenceIndex(after date: Date, anchor: Date, unit: ToDoRecurrenceUnit, interval: Int) -> Int {
      guard date >= anchor else { return 0 }

      let calendar = Calendar.current
      let baseEstimate: Int

      switch unit {
      case .seconds:
         baseEstimate = Int((date.timeIntervalSince(anchor) / Double(interval)).rounded(.down)) + 1
      case .minutes:
         baseEstimate = Int((date.timeIntervalSince(anchor) / Double(interval * 60)).rounded(.down)) + 1
      case .hours:
         baseEstimate = Int((date.timeIntervalSince(anchor) / Double(interval * 3600)).rounded(.down)) + 1
      case .days:
         baseEstimate = max((calendar.dateComponents([.day], from: anchor, to: date).day ?? 0) / interval, 0)
      case .weeks:
         baseEstimate = max((calendar.dateComponents([.weekOfYear], from: anchor, to: date).weekOfYear ?? 0) / interval, 0)
      case .months:
         baseEstimate = max((calendar.dateComponents([.month], from: anchor, to: date).month ?? 0) / interval, 0)
      case .years:
         baseEstimate = max((calendar.dateComponents([.year], from: anchor, to: date).year ?? 0) / interval, 0)
      }

      var index = max(baseEstimate, 0)

      while index > 0,
            let priorDate = recurrenceDate(anchor: anchor, unit: unit, interval: interval, occurrenceIndex: index - 1),
            priorDate > date {
         index -= 1
      }

      while let candidate = recurrenceDate(anchor: anchor, unit: unit, interval: interval, occurrenceIndex: index),
            candidate <= date {
         index += 1
      }

      return index
   }

   private func recurrenceDate(anchor: Date, unit: ToDoRecurrenceUnit, interval: Int, occurrenceIndex: Int) -> Date? {
      Calendar.current.date(
         byAdding: unit.calendarComponent,
         value: interval * occurrenceIndex,
         to: anchor
      )
   }

   private struct ScheduledOccurrence {
      let toDo: ToDo
      let fireDate: Date
      let occurrenceIndex: Int
   }

   private func applyAction(identifier: String, toDoIdentifier: String?, toDoCloudIdentifier: UUID?) async {
      guard let container = modelContainer else { return }

      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         guard let toDo = toDo(
            matchingLocalIdentifier: toDoIdentifier,
            cloudIdentifier: toDoCloudIdentifier,
            in: toDos
         ) else {
            return
         }

         if identifier == markDoneActionIdentifier {
            toDo.transition(to: .done)
            if toDo.calendarEventIdentifier != nil {
               try CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
            }
            LiveActivityService.shared.endActivity(for: toDo)
         } else if identifier.hasPrefix(snoozeActionPrefix),
                   let descriptor = SnoozeDescriptor(
                     identifier: String(identifier.dropFirst(snoozeActionPrefix.count))
                   ) {
            let baseDate = max(toDo.dueDate ?? .now, .now)
            toDo.dueDate = Calendar.current.date(
               byAdding: descriptor.unit.calendarComponent,
               value: descriptor.value,
               to: baseDate
            )
            toDo.markUpdated()
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar),
               toDo.isActive {
               try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
            }
         } else {
            return
         }

         try context.save()
         await MainActor.run {
            SyncCoordinator.shared.scheduleLocalSync()
         }
         await syncScheduledNotifications()
      } catch {
         AppLog.error("Failed to apply notification action: \(error)", logger: AppLog.notifications)
      }
   }

   private func toDo(
      matchingLocalIdentifier localIdentifier: String?,
      cloudIdentifier: UUID?,
      in toDos: [ToDo]
   ) -> ToDo? {
      if let cloudIdentifier,
         let toDo = toDos.first(where: { $0.cloudID == cloudIdentifier }) {
         return toDo
      }

      if let localIdentifier,
         let toDo = toDos.first(where: { persistentIdentifierString(for: $0) == localIdentifier }) {
         return toDo
      }

      return nil
   }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
   func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
   ) {
      let content = notification.request.content

      let options: UNNotificationPresentationOptions
      switch content.interruptionLevel {
      case .passive:
         options = [.list, .badge]
      case .active, .timeSensitive, .critical:
         var opts: UNNotificationPresentationOptions = [.banner, .list, .badge]
         if content.sound != nil {
            opts.insert(.sound)
         }
         options = opts
      @unknown default:
         var opts: UNNotificationPresentationOptions = [.banner, .list, .badge]
         if content.sound != nil {
            opts.insert(.sound)
         }
         options = opts
      }
      completionHandler(options)
   }

   func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
   ) {
      Task { @MainActor in
         defer { completionHandler() }

         let actionIdentifier = response.actionIdentifier
         let content = response.notification.request.content

         let payload = NotificationRouter.payload(
            from: content.userInfo,
            title: content.title,
            body: content.body
         )

         if actionIdentifier == UNNotificationDefaultActionIdentifier,
            let payload {
            NotificationRouter.shared.route(payload: payload)
            return
         }

         let toDoIdentifier = content.userInfo["todoIdentifier"] as? String
         let toDoCloudIdentifier = (content.userInfo["todoCloudIdentifier"] as? String).flatMap(UUID.init(uuidString:))

         guard toDoIdentifier != nil || toDoCloudIdentifier != nil else {
            return
         }

         await NotificationManager.shared.applyAction(
            identifier: actionIdentifier,
            toDoIdentifier: toDoIdentifier,
            toDoCloudIdentifier: toDoCloudIdentifier
         )
      }
   }
}

private struct SnoozeDescriptor: Equatable {
   let unit: SnoozeUnit
   let value: Int

   init(unit: SnoozeUnit, value: Int) {
      self.unit = unit
      self.value = value
   }

   init?(identifier: String) {
      let parts = identifier.split(separator: ".", maxSplits: 1).map(String.init)
      guard parts.count == 2,
            let unit = SnoozeUnit(rawValue: parts[0]),
            let value = Int(parts[1]) else {
         return nil
      }

      self.init(unit: unit, value: value)
   }

   var identifier: String {
      "\(unit.rawValue).\(value)"
   }

   var title: String {
      "Snooze \(unit.displayLabel(for: value))"
   }
}
