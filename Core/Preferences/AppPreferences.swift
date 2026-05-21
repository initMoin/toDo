import Foundation

enum AppPreferences {
   enum Keys {
      static let syncMode = "syncMode"
      static let tagSortOption = "tagSortOption"
      static let tagSortAscending = "tagSortAscending"
      static let tagManagementDefaultTagsExpanded = "tagManagementDefaultTagsExpanded"

      static let toDoListSortOption = "toDoListSortOption"
      static let toDoListSortReversed = "toDoListSortReversed"
      static let createToDoTagsEnabledByDefault = "createToDoTagsEnabledByDefault"
      static let mirrorDueDatesToCalendar = "mirrorDueDatesToCalendar"
      static let deleteCompletedToDosImmediately = "deleteCompletedToDosImmediately"
      static let doneSwipePrimaryAction = "doneSwipePrimaryAction"
      static let snoozeOptions = SnoozePreferences.storageKey
      static let appTimeSource = "appTimeSource"
      static let locationTimeZoneIdentifier = "locationTimeZoneIdentifier"
      static let toDoFocusFilterMode = "todoFocusFilterMode"
      static let appIconBadgePolicy = "appIconBadgePolicy"
      static let notificationSoundOption = "notificationSoundOption"
      static let statsInsightsEnabled = "statsInsightsEnabled"
      static let remotePushDeviceToken = "remotePushDeviceToken"
      static let lastSignInProvider = "lastSignInProvider"
      static let lastSignInProviderUserID = "lastSignInProviderUserID"
      static let mirrorSyncDeletesToDeviceOnly = "mirrorSyncDeletesToDeviceOnly"
      static let lastSuccessfulSyncAt = "lastSuccessfulSyncAt"
      static let pendingStoreMigration = "pendingStoreMigration"
      static let didCompleteOnboarding = "didCompleteOnboarding"
      static let hasCompletedOnboardingOnce = "hasCompletedOnboardingOnce"
      static let currentOnboardingStep = "currentOnboardingStep"
      static let storedTagNormalizationVersion = "storedTagNormalizationVersion"
      static let toDoLifecycleNormalizationVersion = "toDoLifecycleNormalizationVersion"
      static let toDoReminderIntentNormalizationVersion = "toDoReminderIntentNormalizationVersion"
   }

   enum ToDoListSortOption: String, CaseIterable, Identifiable {
      case dueDate
      case creationDate
      case tag
      case dueMonthSections
      case tagSections
      case nanoDoSections

      var id: String { rawValue }

      var title: String {
         switch self {
         case .dueDate:
            return String(localized: "Due Date")
         case .creationDate:
            return String(localized: "Created")
         case .tag:
            return String(localized: "By Tag")
         case .dueMonthSections:
            return String(localized: "Due by Month")
         case .tagSections:
            return String(localized: "Tag Sections")
         case .nanoDoSections:
            return String(localized: "Most NanoDos")
         }
      }

      var compactTitle: String {
         switch self {
         case .dueDate:
            return String(localized: "Due")
         case .creationDate:
            return String(localized: "Created")
         case .tag:
            return String(localized: "By Tag")
         case .dueMonthSections:
            return String(localized: "Month")
         case .tagSections:
            return String(localized: "Tag Groups")
         case .nanoDoSections:
            return String(localized: "NanoDos")
         }
      }

      var usesSections: Bool {
         switch self {
         case .dueDate, .creationDate, .tag:
            return false
         case .dueMonthSections, .tagSections, .nanoDoSections:
            return true
         }
      }

      static var orderingOptions: [Self] {
         allCases.filter { !$0.usesSections }
      }

      static var groupingOptions: [Self] {
         allCases.filter(\.usesSections)
      }
   }

   enum DoneSwipePrimaryAction: String, CaseIterable, Identifiable {
      case archive
      case delete

      var id: String { rawValue }

      var title: String {
         switch self {
         case .archive:
            return String(localized: "Move to Archives")
         case .delete:
            return String(localized: "Delete Permanently")
         }
      }
   }

   enum AppIconBadgePolicy: String, CaseIterable, Identifiable {
      case off
      case activeToDos
      case dueToday
      case overdue
      case timeSensitive
      case scheduledReminders

      var id: String { rawValue }

      var title: String {
         switch self {
         case .off:
            return String(localized: "Off")
         case .activeToDos:
            return String(localized: "Active ToDos")
         case .dueToday:
            return String(localized: "Due Today")
         case .overdue:
            return String(localized: "Overdue")
         case .timeSensitive:
            return String(localized: "Time-Sensitive")
         case .scheduledReminders:
            return String(localized: "Scheduled")
         }
      }

      var detail: String {
         switch self {
         case .off:
            return String(localized: "No app icon badge.")
         case .activeToDos:
            return String(localized: "Counts every active ToDo.")
         case .dueToday:
            return String(localized: "Counts active ToDos due today.")
         case .overdue:
            return String(localized: "Counts active ToDos past due.")
         case .timeSensitive:
            return String(localized: "Counts active time-sensitive ToDos.")
         case .scheduledReminders:
            return String(localized: "Counts active ToDos with a future reminder.")
         }
      }
   }

   enum NotificationSoundOption: String, CaseIterable, Identifiable {
      case defaultSound
      case silent
      case softChime
      case brightPing
      case urgentDouble

      var id: String { rawValue }

      var title: String {
         switch self {
         case .defaultSound:
            return String(localized: "Default")
         case .silent:
            return String(localized: "Silent")
         case .softChime:
            return String(localized: "Soft Chime")
         case .brightPing:
            return String(localized: "Bright Ping")
         case .urgentDouble:
            return String(localized: "Urgent Double")
         }
      }

      var detail: String {
         switch self {
         case .defaultSound:
            return String(localized: "Use the system default notification sound.")
         case .silent:
            return String(localized: "Show reminder alerts without sound.")
         case .softChime:
            return String(localized: "Use a quieter two-note reminder sound.")
         case .brightPing:
            return String(localized: "Use a sharper sound for clear reminders.")
         case .urgentDouble:
            return String(localized: "Use a stronger double alert for due ToDos.")
         }
      }

      var bundledSoundName: String? {
         switch self {
         case .defaultSound, .silent:
            return nil
         case .softChime:
            return "todo-soft-chime.wav"
         case .brightPing:
            return "todo-bright-ping.wav"
         case .urgentDouble:
            return "todo-urgent-double.wav"
         }
      }
   }

   static var defaults: [String: Any] {
      [
         Keys.syncMode: SyncMode.syncEverywhere.rawValue,
         Keys.tagSortOption: TagSortOption.name.rawValue,
         Keys.tagSortAscending: TagSortOption.name.defaultAscending,
         Keys.tagManagementDefaultTagsExpanded: true,
         Keys.toDoListSortOption: ToDoListSortOption.dueDate.rawValue,
         Keys.toDoListSortReversed: false,
         Keys.createToDoTagsEnabledByDefault: false,
         Keys.mirrorDueDatesToCalendar: false,
         Keys.deleteCompletedToDosImmediately: false,
         Keys.doneSwipePrimaryAction: DoneSwipePrimaryAction.delete.rawValue,
         Keys.snoozeOptions: SnoozePreferences.defaultEncodedString,
         Keys.appTimeSource: AppTimeSource.location.rawValue,
         Keys.locationTimeZoneIdentifier: AppTimePreferences.appleParkTimeZoneIdentifier,
         Keys.toDoFocusFilterMode: "all",
         Keys.appIconBadgePolicy: AppIconBadgePolicy.overdue.rawValue,
         Keys.notificationSoundOption: NotificationSoundOption.defaultSound.rawValue,
         Keys.mirrorSyncDeletesToDeviceOnly: true,
      ]
   }

   static let storedTagNormalizationVersion = 1
   static let toDoLifecycleNormalizationVersion = 1
   static let toDoReminderIntentNormalizationVersion = 1

   static func registerDefaults(userDefaults: UserDefaults = .standard) {
      userDefaults.register(defaults: defaults)
   }

   static func resetToDefaults(userDefaults: UserDefaults = .standard) {
      for (key, value) in defaults {
         userDefaults.set(value, forKey: key)
      }
   }

   static func preferredSyncMode(userDefaults: UserDefaults = .standard) -> SyncMode {
      guard let rawValue = userDefaults.string(forKey: Keys.syncMode),
            let mode = SyncMode(rawValue: rawValue)
      else {
         return .syncEverywhere
      }

      return sanitizedSyncMode(mode)
   }

   static func sanitizedSyncMode(_ mode: SyncMode) -> SyncMode {
      guard mode == .iCloud, !CloudKitConfig.isAvailable else {
         return mode
      }

      return .deviceOnly
   }
}

enum SharedStoreLocation {
   static let appGroupIdentifier = "group.dev.iamshift.toDo"

   static func storeURL(for syncMode: SyncMode) -> URL {
      storeDirectory().appending(path: storeFilename(for: syncMode))
   }

   static func legacyStoreURL(for syncMode: SyncMode) -> URL {
      legacyStoreDirectory().appending(path: storeFilename(for: syncMode))
   }

   static func migrateLegacyStoresIfNeeded() {
      let fileManager = FileManager.default

      for syncMode in SyncMode.allCases {
         let sourceURL = legacyStoreURL(for: syncMode)
         let destinationURL = storeURL(for: syncMode)

         guard fileManager.fileExists(atPath: sourceURL.path),
               !fileManager.fileExists(atPath: destinationURL.path)
         else {
            continue
         }

         do {
            try fileManager.createDirectory(
               at: destinationURL.deletingLastPathComponent(),
               withIntermediateDirectories: true
            )

            if isDirectory(sourceURL) {
               try fileManager.copyItem(at: sourceURL, to: destinationURL)
               try fileManager.removeItem(at: sourceURL)
            } else {
               try copyStoreFileSet(from: sourceURL, to: destinationURL)
               try removeStoreFileSet(at: sourceURL)
            }
         } catch {
            AppLog.error("Failed to migrate SwiftData store into App Group for \(syncMode.rawValue): \(error)", logger: AppLog.app)
         }
      }
   }

   static func ensureStoreDirectoryExists(for storeURL: URL) {
      try? FileManager.default.createDirectory(
         at: storeURL.deletingLastPathComponent(),
         withIntermediateDirectories: true
      )
   }

   private static func storeDirectory() -> URL {
      if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
         return appGroupURL.appending(path: "Stores", directoryHint: .isDirectory)
      }

      return legacyStoreDirectory()
   }

   private static func legacyStoreDirectory() -> URL {
      do {
         return try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
         )
      } catch {
         return URL.applicationSupportDirectory
      }
   }

   private static func storeFilename(for syncMode: SyncMode) -> String {
      switch syncMode {
      case .deviceOnly, .syncEverywhere:
         return "default.store"
      case .iCloud:
         return "icloud.store"
      }
   }

   private static func copyStoreFileSet(from sourceURL: URL, to destinationURL: URL) throws {
      let fileManager = FileManager.default
      try fileManager.copyItem(at: sourceURL, to: destinationURL)

      for suffix in ["-shm", "-wal"] {
         let sourceSidecarURL = URL(fileURLWithPath: sourceURL.path + suffix)
         guard fileManager.fileExists(atPath: sourceSidecarURL.path) else { continue }

         let destinationSidecarURL = URL(fileURLWithPath: destinationURL.path + suffix)
         try? fileManager.removeItem(at: destinationSidecarURL)
         try fileManager.copyItem(at: sourceSidecarURL, to: destinationSidecarURL)
      }
   }

   private static func removeStoreFileSet(at storeURL: URL) throws {
      let fileManager = FileManager.default
      try fileManager.removeItem(at: storeURL)

      for suffix in ["-shm", "-wal"] {
         let sidecarURL = URL(fileURLWithPath: storeURL.path + suffix)
         guard fileManager.fileExists(atPath: sidecarURL.path) else { continue }
         try fileManager.removeItem(at: sidecarURL)
      }
   }

   private static func isDirectory(_ url: URL) -> Bool {
      var isDirectory: ObjCBool = false
      FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      return isDirectory.boolValue
   }
}
