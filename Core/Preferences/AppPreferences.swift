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
      static let defaultDueTimeMinutes = "defaultDueTimeMinutes"
      static let locationTimeZoneIdentifier = "locationTimeZoneIdentifier"
      static let toDoFocusFilterMode = "todoFocusFilterMode"
      static let appIconBadgePolicy = "appIconBadgePolicy"
      static let notificationSoundOption = "notificationSoundOption"
      static let customNotificationSoundName = "customNotificationSoundName"
      static let customNotificationSoundDisplayName = "customNotificationSoundDisplayName"
      static let completionSoundOption = "completionSoundOption"
      static let appTheme = "appTheme"
      static let appAppearanceMode = "appAppearanceMode"
      static let statsInsightsEnabled = "statsInsightsEnabled"
      static let appleIntelligenceEnabled = "appleIntelligenceEnabled"
      static let pushInstallationID = "pushInstallationID"
      static let remotePushDeviceToken = "remotePushDeviceToken"
      static let lastSignInProvider = "lastSignInProvider"
      static let lastSignInProviderUserID = "lastSignInProviderUserID"
      static let mirrorSyncDeletesToDeviceOnly = "mirrorSyncDeletesToDeviceOnly"
      static let lastSuccessfulSyncAt = "lastSuccessfulSyncAt"
      static let pendingStoreMigration = "pendingStoreMigration"
      static let didCompleteOnboarding = "didCompleteOnboarding"
      static let hasCompletedOnboardingOnce = "hasCompletedOnboardingOnce"
      static let currentOnboardingStep = "currentOnboardingStep"
      static let hasSeenToDoEditOnboarding = "hasSeenToDoEditOnboarding"
      static let hasShownFirstToDoEditTip = "hasShownFirstToDoEditTip"
      static let storedTagNormalizationVersion = "storedTagNormalizationVersion"
      static let toDoLifecycleNormalizationVersion = "toDoLifecycleNormalizationVersion"
      static let toDoReminderIntentNormalizationVersion = "toDoReminderIntentNormalizationVersion"
   }

   static let defaultDueTimeMinutes = 9 * 60

   static func resolvedDefaultDueTimeMinutes(
      userDefaults: UserDefaults = .standard
   ) -> Int {
      guard userDefaults.object(forKey: Keys.defaultDueTimeMinutes) != nil else {
         return defaultDueTimeMinutes
      }
      return min(max(userDefaults.integer(forKey: Keys.defaultDueTimeMinutes), 0), (24 * 60) - 1)
   }

   static func applyingDefaultDueTime(
      to date: Date,
      userDefaults: UserDefaults = .standard,
      calendar: Calendar = .current
   ) -> Date {
      let minutes = resolvedDefaultDueTimeMinutes(userDefaults: userDefaults)
      return calendar.date(
         bySettingHour: minutes / 60,
         minute: minutes % 60,
         second: 0,
         of: date
      ) ?? date
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
            return String(localized: "Move to Trash")
         }
      }

      var compactTitle: String {
         switch self {
         case .archive:
            return String(localized: "Archive")
         case .delete:
            return String(localized: "Trash")
         }
      }

      var systemImage: String {
         switch self {
         case .archive:
            return "archivebox.fill"
         case .delete:
            return "trash.fill"
         }
      }

      var accessibilityLabel: String {
         switch self {
         case .archive:
            return String(localized: "Archive toDō")
         case .delete:
            return String(localized: "Move toDō to trash")
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
            return String(localized: "Active toDōs")
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
            return String(localized: "Hide the app icon count.")
         case .activeToDos:
            return String(localized: "Count all active toDōs.")
         case .dueToday:
            return String(localized: "Count active toDōs due today.")
         case .overdue:
            return String(localized: "Count active toDōs past due.")
         case .timeSensitive:
            return String(localized: "Count active Time-Sensitive toDōs.")
         case .scheduledReminders:
            return String(localized: "Count active toDōs with a future reminder.")
         }
      }
   }

   enum NotificationSoundOption: String, CaseIterable, Identifiable {
      case defaultSound
      case silent
      case softChime
      case brightPing
      case urgentDouble
      case custom

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
         case .custom:
            return String(localized: "Custom")
         }
      }

      var detail: String {
         switch self {
         case .defaultSound:
            return String(localized: "Use the device default.")
         case .silent:
            return String(localized: "Show alerts without sound.")
         case .softChime:
            return String(localized: "A quieter two-note sound.")
         case .brightPing:
            return String(localized: "A sharper sound for clear reminders.")
         case .urgentDouble:
            return String(localized: "A stronger double alert.")
         case .custom:
            return String(localized: "Use your imported reminder sound.")
         }
      }

      var bundledSoundName: String? {
         switch self {
         case .defaultSound, .silent, .custom:
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

   enum CompletionSoundOption: String, CaseIterable, Identifiable {
      case off
      case soft
      case bright

      var id: String { rawValue }

      var title: String {
         switch self {
         case .off:
            return String(localized: "Off")
         case .soft:
            return String(localized: "Soft")
         case .bright:
            return String(localized: "Bright")
         }
      }

      var detail: String {
         switch self {
         case .off:
            return String(localized: "Keep completions silent.")
         case .soft:
            return String(localized: "A quiet sound when a toDō is done.")
         case .bright:
            return String(localized: "A clearer sound when a toDō is done.")
         }
      }

      var systemSoundID: UInt32? {
         switch self {
         case .off:
            return nil
         case .soft:
            return 1104
         case .bright:
            return 1105
         }
      }
   }

   enum AppAppearanceMode: String, CaseIterable, Identifiable {
      case system
      case light
      case dark

      var id: String { rawValue }

      var title: String {
         switch self {
         case .system:
            return String(localized: "System")
         case .light:
            return String(localized: "Light")
         case .dark:
            return String(localized: "Dark")
         }
      }

      var detail: String {
         switch self {
         case .system:
            return String(localized: "Follow the device appearance setting.")
         case .light:
            return String(localized: "Keep toDō in light mode.")
         case .dark:
            return String(localized: "Keep toDō in dark mode.")
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
         Keys.defaultDueTimeMinutes: defaultDueTimeMinutes,
         Keys.locationTimeZoneIdentifier: AppTimePreferences.appleParkTimeZoneIdentifier,
         Keys.toDoFocusFilterMode: "all",
         Keys.appIconBadgePolicy: AppIconBadgePolicy.overdue.rawValue,
         Keys.notificationSoundOption: NotificationSoundOption.defaultSound.rawValue,
         Keys.customNotificationSoundName: "",
         Keys.customNotificationSoundDisplayName: "",
         Keys.completionSoundOption: CompletionSoundOption.off.rawValue,
         Keys.appTheme: "classic",
         Keys.appAppearanceMode: AppAppearanceMode.system.rawValue,
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
      guard mode != .syncEverywhere || isSupabaseConfiguredForCurrentBundle() else {
         return .deviceOnly
      }

      guard mode == .iCloud, !CloudKitConfig.isAvailable else {
         return mode
      }

      return .deviceOnly
   }

   private static func isSupabaseConfiguredForCurrentBundle() -> Bool {
      guard !Bundle.main.bundlePath.hasSuffix(".appex") else {
         return true
      }

      guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: rawURL),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil,
            let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty,
            let rawRedirectURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_REDIRECT_URL") as? String,
            URL(string: rawRedirectURL) != nil
      else {
         return false
      }

      return true
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
