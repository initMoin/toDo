//
//  ToDoApp.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 2/9/26.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct ToDoApp: App {
   @UIApplicationDelegateAdaptor(PushNotificationAppDelegate.self) private var pushNotificationDelegate
   @Environment(\.scenePhase) private var scenePhase
   @StateObject private var supabaseAuthStore: SupabaseAuthStore
   @StateObject private var purchaseManager = ToDoPurchaseManager.shared
   @StateObject private var collaborationService = ToDoCollaborationService.shared
   @StateObject private var toDoPresentationService = ToDoPresentationService.shared
   @StateObject private var connectivityMonitor = ToDoConnectivityMonitor.shared
   @State private var didRunInitialStartupMaintenance = false
   @State private var isRunningForegroundMaintenance = false
   @AppStorage("todo.lastForegroundRemoteRefreshAt") private var lastForegroundRemoteRefreshAt = 0.0
   @AppStorage(AppPreferences.Keys.appAppearanceMode) private var appAppearanceModeRaw = AppPreferences.AppAppearanceMode.system.rawValue

   private let sharedModelContainer: ModelContainer
   private let isRunningInPreview: Bool
   private let isRunningForScreenshots: Bool
   private let shouldStartSupabaseAuth: Bool
   private let foregroundRemoteRefreshInterval: TimeInterval = 6 * 60 * 60

   @MainActor
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
      let modelContainer = Self.makeModelContainer(
         inMemory: isPreview || isScreenshot,
         preferredSyncMode: preferredSyncMode
      )
      sharedModelContainer = modelContainer

      if !isPreview && !isScreenshot {
         let intentRepository = ToDoIntentRepository(modelContainer: modelContainer)
         AppDependencyManager.shared.add(
            dependency: intentRepository
         )
         ToDoShortcutsProvider.updateAppShortcutParameters()
      }

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
            },
            currentUserIDProvider: {
               SupabaseAuthStore.shared.scopedOwnerUserID
            },
            accessibleCollabIDsProvider: {
               Set(ToDoCollaborationService.shared.collabs.map(\.id))
            }
         )
         LocationReminderService.shared.configure(
            modelContainer: sharedModelContainer,
            currentUserIDProvider: {
               SupabaseAuthStore.shared.scopedOwnerUserID
            },
            accessibleCollabIDsProvider: {
               Set(ToDoCollaborationService.shared.collabs.map(\.id))
            }
         )
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
               AppRootView()
                  .overlay(alignment: .top) {
                     ToDoStoreRecoveryNotice()
                  }
                  .task {
                     guard !didRunInitialStartupMaintenance else { return }
                     didRunInitialStartupMaintenance = true
                     try? await Task.sleep(nanoseconds: 900_000_000)
                     if shouldStartSupabaseAuth {
                        await supabaseAuthStore.start()
                        await purchaseManager.start(account: supabaseAuthStore.commerceAccount)
                        await collaborationService.updateAccount(supabaseAuthStore.commerceAccount)
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
                  .onChange(of: supabaseAuthStore.commerceAccount) { _, account in
                     Task {
                        await purchaseManager.updateAccount(account)
                        await collaborationService.updateAccount(account)
                     }
                  }
                  .onChange(of: supabaseAuthStore.scopedOwnerUserID) { _, _ in
                     refreshAccountScopedSurfaces()
                  }
                  .onChange(of: supabaseAuthStore.profileImageRevision) { _, _ in
                     #if canImport(WatchConnectivity) && os(iOS)
                     WatchConnectivityService.shared.refreshSnapshot()
                     #endif
                  }
                  .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationMembershipDidChange)) { notification in
                     guard let userID = supabaseAuthStore.currentUserID else { return }
                     if let eventUserID = notification.object as? UUID, eventUserID != userID {
                        return
                     }
                     Task {
                        await SyncCoordinator.shared.refreshFromRemote(userID: userID)
                     }
                  }
                  .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationInvitationReceived)) { _ in
                     guard supabaseAuthStore.currentUserID != nil else { return }
                     Task {
                        await collaborationService.refresh()
                     }
                  }
            }
         }
         .appBaseTypography()
         .appAccessibilityAdaptations()
         .appHapticFeedbackHost()
         .preferredColorScheme(preferredAppColorScheme)
         .environmentObject(supabaseAuthStore)
         .environmentObject(purchaseManager)
         .environmentObject(collaborationService)
         .environmentObject(toDoPresentationService)
         .environmentObject(connectivityMonitor)
         .onOpenURL { url in
            guard !isRunningInPreview else { return }
            Task {
               if NavigationCoordinator.shared.route(url: url) {
                  return
               }
               if collaborationService.receiveInvitationURL(url) {
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

      // A profile can change on another device while this app is suspended.
      // Refresh it on foreground so account surfaces and the Home avatar do
      // not remain on the previous cached image.
      if shouldStartSupabaseAuth, supabaseAuthStore.isAuthenticated {
         await supabaseAuthStore.refreshProfile()
      }

      await NotificationManager.shared.refreshAuthorizationStatus()
      NotificationManager.shared.scheduleRefresh()
      LocationReminderService.shared.syncMonitoringFromStore()
      LiveActivityService.shared.startObservingPushTokens()
      LiveActivityService.shared.refresh(from: sharedModelContainer)

      if refreshRemote {
         await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.resolvedAccountID)
         lastForegroundRemoteRefreshAt = Date().timeIntervalSince1970
      }

      WidgetSnapshotService.shared.writeSnapshot(from: sharedModelContainer)

      #if canImport(WatchConnectivity) && os(iOS)
      WatchConnectivityService.shared.refreshSnapshot()
      #endif
   }

   @MainActor
   private func refreshAccountScopedSurfaces() {
      NotificationManager.shared.scheduleRefresh()
      LocationReminderService.shared.syncMonitoringFromStore()
      LiveActivityService.shared.refresh(from: sharedModelContainer)
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
            preconditionFailure("Failed to initialize in-memory SwiftData container: \(error)")
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
         let container = try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
         ToDoStoreRecovery.clearPersistentStoreFailure()
         return container
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
               let container = try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: fallbackConfiguration)
               ToDoStoreRecovery.clearPersistentStoreFailure()
               return container
            } catch {
               AppLog.error("Failed to initialize iCloud fallback SwiftData container: \(error)", logger: AppLog.app)
               return makeRecoveryModelContainer(after: error)
            }
         }

         ensureStoreDirectoryExists(for: storeURL)
         do {
            let container = try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
            ToDoStoreRecovery.clearPersistentStoreFailure()
            return container
         } catch {
            let fallbackMode = AppPreferences.sanitizedSyncMode(preferredSyncMode)
            guard fallbackMode != preferredSyncMode else {
               AppLog.error("Failed to initialize SwiftData container: \(error)", logger: AppLog.app)
               return makeRecoveryModelContainer(after: error)
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
               let container = try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: fallbackConfiguration)
               ToDoStoreRecovery.clearPersistentStoreFailure()
               return container
            } catch {
               AppLog.error("Failed to initialize sanitized fallback SwiftData container: \(error)", logger: AppLog.app)
               return makeRecoveryModelContainer(after: error)
            }
         }
      }
   }

   private static func makeRecoveryModelContainer(after error: Error) -> ModelContainer {
      AppLog.error("Using in-memory recovery SwiftData container after persistent store failure: \(error)", logger: AppLog.app)
      ToDoStoreRecovery.recordPersistentStoreFailure()
      do {
         let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
         )
         return try ModelContainer(for: ToDo.self, Tag.self, NanoDo.self, SyncConflict.self, configurations: configuration)
      } catch {
         preconditionFailure("Failed to initialize recovery SwiftData container: \(error)")
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

         var canonicalTagsByNameAndOwner: [String: Tag] = [:]
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

            let ownerKey = tag.ownerUserID?.uuidString ?? "nil"
            let canonicalKey = "\(ownerKey)|\(normalizedName)"

            if let canonicalTag = canonicalTagsByNameAndOwner[canonicalKey], canonicalTag.id != tag.id {
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

            canonicalTagsByNameAndOwner[canonicalKey] = tag
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
      let release = Tag(name: "release", createdAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now)
      let design = Tag(name: "design", createdAt: calendar.date(byAdding: .day, value: -9, to: now) ?? now)
      let qa = Tag(name: "qa", createdAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now)
      let sync = Tag(name: "sync", createdAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now)
      let testFlight = Tag(name: "testflight", createdAt: calendar.date(byAdding: .day, value: -6, to: now) ?? now)

      [release, design, qa, sync, testFlight].forEach(context.insert)

      let launch = ToDo(
         task: "Ship toDō 3.0 TestFlight",
         notes: "Use toDō to manage the release of toDō: final QA, screenshots, tester notes, localization review, and the build handoff all stay visible in one focused place.",
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
         tags: [release, design, qa, testFlight]
      )

      let screenshotPass = NanoDo(
         task: "Capture launch screenshots",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: 2, to: now),
         isDone: false,
         toDo: launch,
         tag: testFlight
      )
      let testerNotes = NanoDo(
         task: "Send focused tester instructions",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         isDone: true,
         toDo: launch,
         tag: qa
      )
      let liveActivityCheck = NanoDo(
         task: "Verify Live Activity on iPhone + Watch",
         createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
         isDone: false,
         toDo: launch,
         tag: sync
      )
      let localizationSweep = NanoDo(
         task: "Spot-check Arabic, Urdu, Japanese",
         createdAt: calendar.date(byAdding: .hour, value: -18, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: 6, to: now),
         isDone: false,
         toDo: launch,
         tag: qa
      )
      launch.nanoDos = [screenshotPass, testerNotes, liveActivityCheck, localizationSweep]

      let review = ToDo(
         task: "Triage tester feedback",
         notes: "Prioritize crash reports, sync issues, notification behavior, unclear copy, and Watch-specific friction before visual polish.",
         createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
         dueDate: calendar.date(byAdding: .day, value: 1, to: now),
         reminderIntent: .due,
         tags: [release, qa]
      )
      review.nanoDos = [
         NanoDo(task: "Read TestFlight notes", isDone: true, toDo: review, tag: qa),
         NanoDo(task: "Tag follow-up fixes", isDone: false, toDo: review, tag: release)
      ]

      let stats = ToDo(
         task: "Polish Stats dashboard",
         notes: "Make the dashboard feel useful without becoming noisy. Private insights should feel earned, not generic.",
         createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
         dueDate: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now),
         reminderIntent: .due,
         tags: [design, qa]
      )
      stats.nanoDos = [
         NanoDo(task: "Check iPad section rhythm", isDone: false, toDo: stats, tag: design),
         NanoDo(task: "Confirm Private Insights copy", isDone: true, toDo: stats, tag: design)
      ]

      let overdue = ToDo(
         task: "Finish localization QA notes",
         notes: "Overdue item included so the screenshots show urgency and localized date behavior in a realistic release week.",
         createdAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: -3, to: now),
         reminderIntent: .timeSensitive,
         tags: [qa, release]
      )

      let syncAudit = ToDo(
         task: "Confirm sync across iPhone, iPad, Watch",
         createdAt: calendar.date(byAdding: .hour, value: -12, to: now) ?? now,
         dueDate: calendar.date(byAdding: .hour, value: 8, to: now),
         reminderIntent: .due,
         locationReminderLatitude: 37.3317,
         locationReminderLongitude: -122.0307,
         locationReminderRadius: 180,
         locationReminderTrigger: .arriving,
         locationReminderLabel: "Test desk",
         tags: [sync, qa]
      )

      let done = ToDo(
         task: "Lock v3.0 build number",
         createdAt: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
         updatedAt: calendar.date(byAdding: .hour, value: -6, to: now),
         lifecycleState: .done,
         isDone: true,
         tags: [release]
      )

      [launch, review, stats, overdue, syncAudit, done].forEach(context.insert)
      [screenshotPass, testerNotes, liveActivityCheck, localizationSweep].forEach(context.insert)
      review.nanoDos.forEach(context.insert)
      stats.nanoDos.forEach(context.insert)

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
