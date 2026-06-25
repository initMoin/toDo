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
            return String(localized: "Not Ready")
         case .requesting:
            return String(localized: "Getting Ready")
         case .registered:
            return String(localized: "Ready")
         case .failed:
            return String(localized: "Unavailable")
         }
      }
   }

   var pushReadinessDetail: String {
      switch registrationState {
      case .idle:
         return String(localized: "This device is not ready for remote reminders yet.")
      case .requesting:
         return String(localized: "toDō is getting this device ready for remote reminders.")
      case .registered:
         return String(localized: "Remote reminders are ready on this device.")
      case .failed:
         return String(localized: "Remote reminders could not be prepared. Try again from Settings.")
      }
   }

   @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
   @Published private(set) var timeSensitiveSetting: UNNotificationSetting = .notSupported
   @Published private(set) var registrationState: RegistrationState = .idle

   @Published private(set) var currentAPNSToken: String?

   private let center = UNUserNotificationCenter.current()
   private let notificationPrefix = "todo.due."
   private let nanoDoNotificationPrefix = "todo.nanodo.due."
   private let categoryIdentifier = "TODO_DUE_REMINDER"
   private let markDoneActionIdentifier = "todo.markDone"
   private let snoozeActionPrefix = "todo.snooze."
   private static let soundPreviewNotificationPrefix = "todo.sound-preview."
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
      guard Self.isNotificationDeliveryAllowed(authorizationStatus) else {
         return
      }

      guard let remoteNotificationRegistrar else {
         registrationState = .idle
         return
      }

      registrationState = .requesting
      remoteNotificationRegistrar()
   }

   func scheduleSoundPreviewNotification(after seconds: TimeInterval = 3) async throws {
      let settings = await center.notificationSettings()
      guard Self.isNotificationDeliveryAllowed(settings.authorizationStatus) else {
         return
      }

      registerNotificationCategories()
      removeSoundPreviewNotifications()

      let content = NotificationContentBuilder.content(
         for: .test,
         title: String(localized: "toDō sound check"),
         body: String(localized: "This reminder uses your selected notification sound."),
         isTimeSensitive: false,
         isQuiet: false,
         soundOption: preferredSoundOption,
         customSoundName: preferredCustomSoundName
      )
      content.badge = nil

      let trigger = UNTimeIntervalNotificationTrigger(
         timeInterval: max(seconds, 1),
         repeats: false
      )
      let identifier = "\(Self.soundPreviewNotificationPrefix)\(UUID().uuidString)"
      let request = UNNotificationRequest(
         identifier: identifier,
         content: content,
         trigger: trigger
      )

      try await center.add(request)
      scheduleSoundPreviewCleanup(identifier: identifier, after: max(seconds, 1) + 2)
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
         #if !os(macOS)
         await SupabaseAuthStore.shared.syncCurrentDeviceTokenIfPossible()
         #endif
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

   private func scheduleSoundPreviewCleanup(identifier: String, after delay: TimeInterval) {
      Task { [center] in
         let nanoseconds = UInt64(max(delay, 1) * 1_000_000_000)
         try? await Task.sleep(nanoseconds: nanoseconds)
         center.removeDeliveredNotifications(withIdentifiers: [identifier])
         center.removePendingNotificationRequests(withIdentifiers: [identifier])
      }
   }

   private func removeSoundPreviewNotifications() {
      let prefix = Self.soundPreviewNotificationPrefix
      center.getPendingNotificationRequests { requests in
         let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

         guard !identifiers.isEmpty else { return }
         UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
      }

      center.getDeliveredNotifications { notifications in
         let identifiers = notifications
            .map(\.request.identifier)
            .filter { $0.hasPrefix(prefix) }

         guard !identifiers.isEmpty else { return }
         UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
      }
   }

   func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> RemoteNotificationHandlingResult {
      if isRemoteSyncRefreshPayload(userInfo) {
         #if os(macOS)
         return .noData
         #else
         guard let userID = SupabaseAuthStore.shared.currentUserID else {
            return .noData
         }

         await SyncCoordinator.shared.refreshFromRemote(userID: userID)
         await syncScheduledNotifications()
         return .newData
         #endif
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
         let nanoDos = try context.fetch(FetchDescriptor<NanoDo>())
         let now = Date()
         let activeToDos = toDos.filter(\.isActive)
         let futureDueToDos = activeToDos.filter { toDo in
            toDo.dueDate.map { $0 > now } ?? false
         }
         let schedulableOccurrences = limitedScheduledOccurrences(for: activeToDos, now: now)
         let schedulableNanoDos = nanoDos
            .filter { nanoDo in
               !nanoDo.isDone
                  && nanoDo.toDo?.isActive == true
                  && nanoDo.dueDate.map { $0 > now } == true
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
         let settings = await center.notificationSettings()
         authorizationStatus = settings.authorizationStatus
         timeSensitiveSetting = settings.timeSensitiveSetting
         AppLog.info(
            "Notification sync started: auth=\(Self.authorizationDescription(settings.authorizationStatus)), alert=\(Self.settingDescription(settings.alertSetting)), sound=\(Self.settingDescription(settings.soundSetting)), timeSensitive=\(Self.settingDescription(settings.timeSensitiveSetting)), sourceToDos=\(toDos.count), active=\(activeToDos.count), futureDue=\(futureDueToDos.count), schedulable=\(schedulableOccurrences.count).",
            logger: AppLog.notifications
         )
         await updateAppIconBadge(for: toDos, now: now)

         guard Self.isNotificationDeliveryAllowed(settings.authorizationStatus) else {
            AppLog.info(
               "Notification scheduling skipped because permission is \(Self.authorizationDescription(settings.authorizationStatus)).",
               logger: AppLog.notifications
            )
            return
         }

         let pendingIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter {
               $0.hasPrefix(notificationPrefix)
                  || $0.hasPrefix(nanoDoNotificationPrefix)
            }

         if !pendingIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: pendingIdentifiers)
         }

         var scheduledCount = 0
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
               soundOption: preferredSoundOption,
               customSoundName: preferredCustomSoundName
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
            scheduledCount += 1
         }
         let remainingCapacity = max(maxScheduledNotificationRequests - scheduledCount, 0)
         for nanoDo in schedulableNanoDos.prefix(remainingCapacity) {
            guard let fireDate = nanoDo.dueDate,
                  let parentToDo = nanoDo.toDo else { continue }
            let content = NotificationContentBuilder.content(
               for: .toDoDue,
               title: String(localized: "NanoDo: due"),
               body: nanoDo.task.trimmingCharacters(in: .whitespacesAndNewlines),
               isTimeSensitive: false,
               isQuiet: false,
               soundOption: preferredSoundOption,
               customSoundName: preferredCustomSoundName
            )
            content.userInfo = [
               "schemaVersion": 1,
               "type": RemoteNotificationType.toDoDue.rawValue,
               "todoIdentifier": persistentIdentifierString(for: parentToDo),
               "nanoDoIdentifier": persistentIdentifierString(for: nanoDo),
               "isNanoDo": true,
               "isRecurring": false,
               "isTimeSensitive": false
            ]
            let triggerDate = Calendar.current.dateComponents(
               [.year, .month, .day, .hour, .minute, .second],
               from: fireDate
            )
            try await center.add(UNNotificationRequest(
               identifier: nanoDoNotificationIdentifier(for: nanoDo, fireDate: fireDate),
               content: content,
               trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            ))
            scheduledCount += 1
         }
         let nextFireDate = schedulableOccurrences.first?.fireDate.formatted(date: .numeric, time: .standard) ?? "none"
         AppLog.info(
            "Notification sync finished: scheduled=\(scheduledCount), removedPending=\(pendingIdentifiers.count), nextFire=\(nextFireDate).",
            logger: AppLog.notifications
         )
      } catch {
         AppLog.error("Failed to sync notifications: \(error)", logger: AppLog.notifications)
      }
   }

   private static func authorizationDescription(_ status: UNAuthorizationStatus) -> String {
      switch status {
      case .notDetermined:
         return "notDetermined"
      case .denied:
         return "denied"
      case .authorized:
         return "authorized"
      case .provisional:
         return "provisional"
      case .ephemeral:
         return "ephemeral"
      @unknown default:
         return "unknown"
      }
   }

   private static func settingDescription(_ setting: UNNotificationSetting) -> String {
      switch setting {
      case .notSupported:
         return "notSupported"
      case .disabled:
         return "disabled"
      case .enabled:
         return "enabled"
      @unknown default:
         return "unknown"
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
         title: String(localized: "Mark Done"),
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

   private func nanoDoNotificationIdentifier(for nanoDo: NanoDo, fireDate: Date) -> String {
      nanoDoNotificationPrefix + persistentIdentifierString(for: nanoDo) + ".\(Int(fireDate.timeIntervalSince1970))"
   }

   private func notificationTitle(for toDo: ToDo, fireDate: Date) -> String {
      guard toDo.dueDate != nil else {
         return String(localized: "toDō reminder")
      }

      if fireDate < .now {
         return String(localized: "toDō: overdue")
      }

      if toDo.isRecurring {
         return String(localized: "toDō: repeating")
      }

      switch toDo.reminderIntent {
      case .soft:
         return String(localized: "toDō reminder")
      case .due, .timeSensitive:
         return String(localized: "toDō: due")
      }
   }

   private func notificationBody(for toDo: ToDo) -> String {
      let task = toDo.task.trimmingCharacters(in: .whitespacesAndNewlines)
      return task.isEmpty ? String(localized: "Open toDō to review this reminder.") : task
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

   private func persistentIdentifierString(for nanoDo: NanoDo) -> String {
      String(describing: nanoDo.id)
   }

   private var preferredSoundOption: AppPreferences.NotificationSoundOption {
      let rawValue = UserDefaults.standard.string(forKey: AppPreferences.Keys.notificationSoundOption)
      return rawValue.flatMap(AppPreferences.NotificationSoundOption.init(rawValue:)) ?? .defaultSound
   }

   private var preferredCustomSoundName: String? {
      NotificationSoundLibrary.currentCustomSoundName()
   }

   private func notificationSound(for option: AppPreferences.NotificationSoundOption) -> UNNotificationSound? {
      guard option != .silent else { return nil }

      if option == .custom,
         let customSoundName = preferredCustomSoundName {
         return UNNotificationSound(named: UNNotificationSoundName(rawValue: customSoundName))
      }

      if let bundledSoundName = option.bundledSoundName {
         return UNNotificationSound(named: UNNotificationSoundName(rawValue: bundledSoundName))
      }

      return .default
   }

   private static func isNotificationDeliveryAllowed(_ status: UNAuthorizationStatus) -> Bool {
      switch status {
      case .authorized, .provisional:
         return true
      #if !os(macOS)
      case .ephemeral:
         return true
      #endif
      default:
         return false
      }
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
         toDoTitle: toDoTitle?.isEmpty == false ? toDoTitle! : "Review toDō",
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

   private func limitedScheduledOccurrences(for activeToDos: [ToDo], now: Date) -> [ScheduledOccurrence] {
      var occurrences: [ScheduledOccurrence] = []
      occurrences.reserveCapacity(maxScheduledNotificationRequests)

      for toDo in activeToDos {
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

   private func applyAction(
      identifier: String,
      toDoIdentifier: String?,
      toDoCloudIdentifier: UUID?,
      nanoDoIdentifier: String?
   ) async {
      guard let container = modelContainer else { return }

      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         if let nanoDoIdentifier {
            let nanoDos = try context.fetch(FetchDescriptor<NanoDo>())
            guard let nanoDo = nanoDos.first(where: {
               persistentIdentifierString(for: $0) == nanoDoIdentifier
            }) else {
               return
            }

            if identifier == markDoneActionIdentifier {
               nanoDo.isDone = true
               nanoDo.markUpdated()
               _ = nanoDo.toDo?.completeIfAllNanoDosAreDone()
            } else if identifier.hasPrefix(snoozeActionPrefix),
                      let descriptor = SnoozeDescriptor(
                        identifier: String(identifier.dropFirst(snoozeActionPrefix.count))
                      ) {
               let baseDate = max(nanoDo.dueDate ?? .now, .now)
               nanoDo.dueDate = Calendar.current.date(
                  byAdding: descriptor.unit.calendarComponent,
                  value: descriptor.value,
                  to: baseDate
               )
               nanoDo.markUpdated()
            } else {
               return
            }

            try context.save()
            SyncCoordinator.shared.scheduleLocalSync()
            await syncScheduledNotifications()
            return
         }
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
            #if !os(macOS)
            LiveActivityService.shared.endActivity(for: toDo)
            #endif
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
      let isSoundPreview = notification.request.identifier.hasPrefix(Self.soundPreviewNotificationPrefix)

      let options: UNNotificationPresentationOptions
      if isSoundPreview {
         var opts: UNNotificationPresentationOptions = [.banner]
         if content.sound != nil {
            opts.insert(.sound)
         }
         options = opts
      } else {
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
         let nanoDoIdentifier = content.userInfo["nanoDoIdentifier"] as? String

         guard toDoIdentifier != nil || toDoCloudIdentifier != nil else {
            return
         }

         await NotificationManager.shared.applyAction(
            identifier: actionIdentifier,
            toDoIdentifier: toDoIdentifier,
            toDoCloudIdentifier: toDoCloudIdentifier,
            nanoDoIdentifier: nanoDoIdentifier
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
