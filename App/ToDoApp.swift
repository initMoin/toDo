//
//  ToDoApp.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 2/9/26.
//

import SwiftUI
import SwiftData

@main
struct ToDoApp: App {
   @UIApplicationDelegateAdaptor(PushNotificationAppDelegate.self) private var pushNotificationDelegate
   @Environment(\.scenePhase) private var scenePhase
   @StateObject private var supabaseAuthStore: SupabaseAuthStore
   @State private var didRunInitialStartupMaintenance = false
   @State private var isRunningForegroundMaintenance = false
   @AppStorage("todo.lastForegroundRemoteRefreshAt") private var lastForegroundRemoteRefreshAt = 0.0
   @AppStorage(AppPreferences.Keys.appAppearanceMode) private var appAppearanceModeRaw = AppPreferences.AppAppearanceMode.system.rawValue

   private let sharedModelContainer: ModelContainer
   private let isRunningInPreview: Bool
   private let isRunningForScreenshots: Bool
   private let shouldStartSupabaseAuth: Bool
   private let foregroundRemoteRefreshInterval: TimeInterval = 6 * 60 * 60

   init() {
      let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
      let isScreenshot = ProcessInfo.processInfo.arguments.contains("-UITestScreenshotMode")
      isRunningInPreview = isPreview
      isRunningForScreenshots = isScreenshot
      shouldStartSupabaseAuth = !isPreview && !isScreenshot
      _supabaseAuthStore = StateObject(wrappedValue: isPreview ? .preview : .shared)
      AppPreferences.registerDefaults()
      if isScreenshot {
         Self.prepareScreenshotPreferences()
      }
      let preferredSyncMode = AppPreferences.preferredSyncMode()
      let storedSyncMode = UserDefaults.standard.string(forKey: AppPreferences.Keys.syncMode).flatMap(SyncMode.init(rawValue:))
      if storedSyncMode != preferredSyncMode {
         UserDefaults.standard.set(preferredSyncMode.rawValue, forKey: AppPreferences.Keys.syncMode)
      }
      sharedModelContainer = Self.makeModelContainer(
         inMemory: isPreview || isScreenshot,
         preferredSyncMode: preferredSyncMode
      )

      if isScreenshot {
         Self.seedScreenshotDataIfNeeded(in: sharedModelContainer)
      } else if !isPreview {
         MigrationService.shared.runPendingStoreMigrationIfNeeded(
            into: sharedModelContainer,
            activeMode: preferredSyncMode
         )
         Self.runPendingMigrations(in: sharedModelContainer)
         NotificationManager.shared.configure(
            modelContainer: sharedModelContainer,
            remoteNotificationRegistrar: {
               PushNotificationAppDelegate.registerForRemoteNotifications()
            }
         )
         LocationReminderService.shared.configure(modelContainer: sharedModelContainer)
         SyncCoordinator.shared.configure(
            modelContainer: sharedModelContainer,
            configuredSyncMode: preferredSyncMode
         )
         #if canImport(WatchConnectivity) && os(iOS)
         WatchConnectivityService.shared.configure(modelContainer: sharedModelContainer)
         #endif
      }
   }

   var body: some Scene {
      WindowGroup {
         Group {
            if isRunningInPreview {
               PreviewBootstrapView()
            } else {
               ToDosView()
                  .task {
                     guard !didRunInitialStartupMaintenance else { return }
                     didRunInitialStartupMaintenance = true
                     try? await Task.sleep(nanoseconds: 900_000_000)
                     if shouldStartSupabaseAuth {
                        await supabaseAuthStore.start()
                     }
                     await runForegroundMaintenance(refreshRemote: shouldRefreshRemoteOnForeground)
                  }
                  .onChange(of: scenePhase) { _, newPhase in
                     guard !isRunningInPreview, !isRunningForScreenshots else { return }
                     supabaseAuthStore.handleScenePhase(newPhase)
                     guard newPhase == .active else { return }
                     Task {
                        await runForegroundMaintenance(refreshRemote: shouldRefreshRemoteOnForeground)
                     }
                  }
            }
         }
         .appBaseTypography()
         .preferredColorScheme(preferredAppColorScheme)
         .environmentObject(supabaseAuthStore)
         .onOpenURL { url in
            guard !isRunningInPreview else { return }
            Task {
               if NavigationCoordinator.shared.route(url: url) {
                  return
               }
               await supabaseAuthStore.handleIncomingURL(url)
            }
         }
      }
      .modelContainer(sharedModelContainer)
   }

   @MainActor
   private func runForegroundMaintenance(refreshRemote: Bool) async {
      guard !isRunningForegroundMaintenance else { return }
      isRunningForegroundMaintenance = true
      defer { isRunningForegroundMaintenance = false }

      await NotificationManager.shared.refreshAuthorizationStatus()
      NotificationManager.shared.scheduleRefresh()
      LocationReminderService.shared.syncMonitoringFromStore()
      LiveActivityService.shared.startObservingPushTokens()
      LiveActivityService.shared.refresh(from: sharedModelContainer)

      if refreshRemote {
         await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.currentUserID)
         lastForegroundRemoteRefreshAt = Date().timeIntervalSince1970
      }

      WidgetSnapshotService.shared.writeSnapshot(from: sharedModelContainer)

      #if canImport(WatchConnectivity) && os(iOS)
      WatchConnectivityService.shared.refreshSnapshot()
      #endif
   }

   private var shouldRefreshRemoteOnForeground: Bool {
      Date().timeIntervalSince1970 - lastForegroundRemoteRefreshAt >= foregroundRemoteRefreshInterval
   }

   private var preferredAppColorScheme: ColorScheme? {
      switch AppPreferences.AppAppearanceMode(rawValue: appAppearanceModeRaw) ?? .system {
      case .system:
         return nil
      case .light:
         return .light
      case .dark:
         return .dark
      }
   }

   private static func prepareScreenshotPreferences() {
      UserDefaults.standard.set(true, forKey: AppPreferences.Keys.didCompleteOnboarding)
      UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboardingOnce)
      UserDefaults.standard.set(SyncMode.deviceOnly.rawValue, forKey: AppPreferences.Keys.syncMode)
      UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.currentOnboardingStep)
   }

   private static func makeModelContainer(
      inMemory: Bool = false,
      preferredSyncMode: SyncMode = AppPreferences.preferredSyncMode()
   ) -> ModelContainer {
      if inMemory {
         do {
            let configuration = ModelConfiguration(
               isStoredInMemoryOnly: true,
               cloudKitDatabase: .none
            )
            return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
         } catch {
            fatalError("Failed to initialize in-memory SwiftData container: \(error)")
         }
      }

      SharedStoreLocation.migrateLegacyStoresIfNeeded()
      let storeURL = defaultStoreURL(for: preferredSyncMode)
      ensureStoreDirectoryExists(for: storeURL)
      let configuration = ModelConfiguration(
         "ToDo",
         url: storeURL,
         cloudKitDatabase: CloudKitConfig.database(for: preferredSyncMode)
      )

      do {
         return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
      } catch {
         if preferredSyncMode == .iCloud {
            let fallbackMode: SyncMode = .deviceOnly
            UserDefaults.standard.set(fallbackMode.rawValue, forKey: AppPreferences.Keys.syncMode)
            let fallbackURL = defaultStoreURL(for: fallbackMode)
            ensureStoreDirectoryExists(for: fallbackURL)
            let fallbackConfiguration = ModelConfiguration(
               "ToDo",
               url: fallbackURL,
               cloudKitDatabase: CloudKitConfig.database(for: fallbackMode)
            )

            do {
               return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: fallbackConfiguration)
            } catch {
               fatalError("Failed to initialize SwiftData container: \(error)")
            }
         }

         ensureStoreDirectoryExists(for: storeURL)
         do {
            return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
         } catch {
            let fallbackMode = AppPreferences.sanitizedSyncMode(preferredSyncMode)
            guard fallbackMode != preferredSyncMode else {
               fatalError("Failed to initialize SwiftData container: \(error)")
            }

            UserDefaults.standard.set(fallbackMode.rawValue, forKey: AppPreferences.Keys.syncMode)
            let fallbackURL = defaultStoreURL(for: fallbackMode)
            ensureStoreDirectoryExists(for: fallbackURL)
            let fallbackConfiguration = ModelConfiguration(
               "ToDo",
               url: fallbackURL,
               cloudKitDatabase: CloudKitConfig.database(for: fallbackMode)
            )

            do {
               return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: fallbackConfiguration)
            } catch {
               fatalError("Failed to initialize SwiftData container: \(error)")
            }
         }
      }
   }

   private static func defaultStoreURL(for syncMode: SyncMode) -> URL {
      SharedStoreLocation.storeURL(for: syncMode)
   }

   private static func ensureStoreDirectoryExists(for storeURL: URL) {
      SharedStoreLocation.ensureStoreDirectoryExists(for: storeURL)
   }

   @MainActor
   private static func seedScreenshotDataIfNeeded(in container: ModelContainer) {
      ScreenshotDataSeeder.seedIfNeeded(in: container.mainContext)
   }

   private static func runPendingMigrations(
      in container: ModelContainer,
      userDefaults: UserDefaults = .standard
   ) {
      let storedTagVersion = userDefaults.integer(forKey: AppPreferences.Keys.storedTagNormalizationVersion)
      if storedTagVersion < AppPreferences.storedTagNormalizationVersion,
         normalizeStoredTags(in: container) {
         userDefaults.set(
            AppPreferences.storedTagNormalizationVersion,
            forKey: AppPreferences.Keys.storedTagNormalizationVersion
         )
      }

      let lifecycleVersion = userDefaults.integer(forKey: AppPreferences.Keys.toDoLifecycleNormalizationVersion)
      if lifecycleVersion < AppPreferences.toDoLifecycleNormalizationVersion,
         normalizeToDoLifecycleStates(in: container) {
         userDefaults.set(
            AppPreferences.toDoLifecycleNormalizationVersion,
            forKey: AppPreferences.Keys.toDoLifecycleNormalizationVersion
         )
      }

      let reminderIntentVersion = userDefaults.integer(forKey: AppPreferences.Keys.toDoReminderIntentNormalizationVersion)
      if reminderIntentVersion < AppPreferences.toDoReminderIntentNormalizationVersion,
         normalizeToDoReminderIntents(in: container) {
         userDefaults.set(
            AppPreferences.toDoReminderIntentNormalizationVersion,
            forKey: AppPreferences.Keys.toDoReminderIntentNormalizationVersion
         )
      }
   }

   @discardableResult
   private static func normalizeStoredTags(in container: ModelContainer) -> Bool {
      let context = ModelContext(container)

      do {
         let tags = try context.fetch(
            FetchDescriptor<Tag>(
               sortBy: [
                  SortDescriptor(\.createdAt, order: .forward),
                  SortDescriptor(\.name, order: .forward)
               ]
            )
         )
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         let nanoDos = try context.fetch(FetchDescriptor<NanoDo>())

         var canonicalTagsByName: [String: Tag] = [:]
         let toDosByTagID = Dictionary(grouping: toDos.flatMap { toDo in
            toDo.effectiveTags.map { tag in (tag.id, toDo) }
         }, by: \.0)
            .mapValues { pairs in pairs.map(\.1) }
         let nanoDosByTagID = Dictionary(grouping: nanoDos.compactMap { nanoDo in
            nanoDo.tag.map { tag in (tag.id, nanoDo) }
         }, by: \.0)
            .mapValues { pairs in pairs.map(\.1) }
         var didChange = false

         for tag in tags {
            let normalizedName = Tag.normalizeName(tag.name)

            guard !normalizedName.isEmpty else {
               for toDo in toDosByTagID[tag.id, default: []] {
                  let remainingTags = toDo.effectiveTags.filter { $0.id != tag.id }
                  if remainingTags.count != toDo.effectiveTags.count {
                     toDo.setSelectedTags(remainingTags)
                     didChange = true
                  }
               }

               for nanoDo in nanoDosByTagID[tag.id, default: []] {
                  nanoDo.tag = nil
                  didChange = true
               }

               context.delete(tag)
               didChange = true
               continue
            }

            if let canonicalTag = canonicalTagsByName[normalizedName], canonicalTag.id != tag.id {
               for toDo in toDosByTagID[tag.id, default: []] {
                  let effectiveTags = toDo.effectiveTags
                  let mergedTags = effectiveTags.map { currentTag in
                     currentTag.id == tag.id ? canonicalTag : currentTag
                  }
                  toDo.setSelectedTags(mergedTags)
                  didChange = true
               }

               for nanoDo in nanoDosByTagID[tag.id, default: []] {
                  nanoDo.tag = canonicalTag
                  didChange = true
               }

               context.delete(tag)
               didChange = true
               continue
            }

            if tag.name != normalizedName {
               tag.name = normalizedName
               didChange = true
            }

            canonicalTagsByName[normalizedName] = tag
         }

         if didChange {
            try context.save()
         }
         return true
      } catch {
         AppLog.error("Failed to normalize stored tags: \(error)", logger: AppLog.app)
         return false
      }
   }

   @discardableResult
   private static func normalizeToDoLifecycleStates(in container: ModelContainer) -> Bool {
      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         var didChange = false

         for toDo in toDos {
            let resolvedState = ToDoState(rawValue: toDo.lifecycleStateRaw) ?? (toDo.isDone ? .done : .active)

            if toDo.lifecycleStateRaw != resolvedState.rawValue {
               toDo.lifecycleStateRaw = resolvedState.rawValue
               didChange = true
            }

            let legacyDoneValue = resolvedState == .done
            if toDo.isDone != legacyDoneValue {
               toDo.isDone = legacyDoneValue
               didChange = true
            }
         }

         if didChange {
            try context.save()
         }
         return true
      } catch {
         AppLog.error("Failed to normalize ToDo lifecycle states: \(error)", logger: AppLog.app)
         return false
      }
   }

   @discardableResult
   private static func normalizeToDoReminderIntents(in container: ModelContainer) -> Bool {
      let context = ModelContext(container)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         var didChange = false

         for toDo in toDos {
            let resolvedIntent = ToDoReminderIntent(rawValue: toDo.reminderIntentRaw)
            ?? (toDo.dueDate == nil ? .soft : .due)

            if toDo.reminderIntentRaw != resolvedIntent.rawValue {
               toDo.reminderIntentRaw = resolvedIntent.rawValue
               didChange = true
            }
         }

         if didChange {
            try context.save()
         }

         return true
      } catch {
         AppLog.error("Failed to normalize ToDo reminder intents: \(error)", logger: AppLog.app)
         return false
      }
   }
}

@MainActor
private enum ScreenshotDataSeeder {
   static func seedIfNeeded(in context: ModelContext) {
      let descriptor = FetchDescriptor<ToDo>()
      if let existingCount = try? context.fetchCount(descriptor), existingCount > 0 {
         return
      }

      let calendar = Calendar.current
      let now = Date()
      let personal = Tag(name: "personal", createdAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now)
      let work = Tag(name: "work", createdAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now)
      let health = Tag(name: "health", createdAt: calendar.date(byAdding: .day, value: -6, to: now) ?? now)
      let planning = Tag(name: "planning", createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now)

      [personal, work, health, planning].forEach(context.insert)

      let hello = ToDo(
         task: "Hello world!",
         notes: "Use this ToDo to verify the full detail view: due date, tags, NanoDos, recurrence, and notes should all feel intentional.",
         createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
         updatedAt: calendar.date(byAdding: .hour, value: -2, to: now),
         dueDate: calendar.date(byAdding: .hour, value: 4, to: now),
         reminderIntent: .timeSensitive,
         recurrenceUnit: .days,
         recurrenceInterval: 2,
         recurrenceMode: .finite,
         recurrenceCount: 3,
         recurrenceAnchorDate: now,
         locationReminderLatitude: 37.3349,
         locationReminderLongitude: -122.0090,
         locationReminderRadius: 250,
         locationReminderTrigger: .arriving,
         locationReminderLabel: "Apple Park",
         tags: [personal, work, planning]
      )

      let outline = NanoDo(
         task: "Confirm localized screenshots",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: 2, to: now),
         isDone: false,
         toDo: hello,
         tag: work
      )
      let polish = NanoDo(
         task: "Review visual spacing",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         isDone: true,
         toDo: hello,
         tag: planning
      )
      let send = NanoDo(
         task: "Capture App Store screenshots",
         createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
         isDone: false,
         toDo: hello,
         tag: personal
      )
      hello.nanoDos = [outline, polish, send]

      let review = ToDo(
         task: "Review beta feedback",
         notes: "Prioritize crash reports, sync issues, and unclear interaction copy before visual polish.",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         dueDate: calendar.date(byAdding: .day, value: 1, to: now),
         reminderIntent: .due,
         tags: [work, planning]
      )
      review.nanoDos = [
         NanoDo(task: "Read TestFlight notes", isDone: true, toDo: review, tag: work),
         NanoDo(task: "Tag follow-up fixes", isDone: false, toDo: review, tag: planning)
      ]

      let workout = ToDo(
         task: "Evening walk",
         notes: "Keep the reminder gentle unless the day is packed.",
         createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
         dueDate: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now),
         reminderIntent: .soft,
         tags: [health, personal]
      )

      let overdue = ToDo(
         task: "Send invoice",
         notes: "Overdue item included so the list looks like an active user's real day.",
         createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: -3, to: now),
         reminderIntent: .timeSensitive,
         tags: [work]
      )

      let groceries = ToDo(
         task: "Pick up groceries",
         createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: 8, to: now),
         reminderIntent: .due,
         locationReminderLatitude: 37.3318,
         locationReminderLongitude: -122.0312,
         locationReminderRadius: 180,
         locationReminderTrigger: .arriving,
         locationReminderLabel: "Market",
         tags: [personal]
      )

      let done = ToDo(
         task: "Archive old screenshots",
         createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
         updatedAt: calendar.date(byAdding: .hour, value: -6, to: now),
         lifecycleState: .done,
         isDone: true,
         tags: [planning]
      )

      [hello, review, workout, overdue, groceries, done].forEach(context.insert)
      [outline, polish, send].forEach(context.insert)
      review.nanoDos.forEach(context.insert)

      do {
         try context.save()
      } catch {
         assertionFailure("Failed to seed screenshot data: \(error)")
      }
   }
}

private struct PreviewBootstrapView: View {
   var body: some View {
      Color.clear
   }
}
