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
    // APNs still enters through app-delegate callbacks. This adaptor keeps the app on
    // the SwiftUI lifecycle while confining UIKit exposure to the notification bridge.
    @UIApplicationDelegateAdaptor(PushNotificationAppDelegate.self) private var pushNotificationDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var supabaseAuthStore: SupabaseAuthStore

    private let sharedModelContainer: ModelContainer
    private let isRunningInPreview: Bool
    private let shouldStartSupabaseAuth: Bool

    init() {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isRunningInPreview = isPreview
        shouldStartSupabaseAuth = !isPreview
        _supabaseAuthStore = StateObject(wrappedValue: isPreview ? .preview : .shared)
        AppPreferences.registerDefaults()
        let preferredSyncMode = AppPreferences.preferredSyncMode()
        let storedSyncMode = UserDefaults.standard.string(forKey: AppPreferences.Keys.syncMode).flatMap(SyncMode.init(rawValue:))
        if storedSyncMode != preferredSyncMode {
            UserDefaults.standard.set(preferredSyncMode.rawValue, forKey: AppPreferences.Keys.syncMode)
        }
        sharedModelContainer = Self.makeModelContainer(
            inMemory: isPreview,
            preferredSyncMode: preferredSyncMode
        )

        if !isPreview {
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
            SyncCoordinator.shared.configure(
                modelContainer: sharedModelContainer,
                configuredSyncMode: preferredSyncMode
            )
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
                            guard shouldStartSupabaseAuth else { return }
                            await SyncCoordinator.shared.start(userID: supabaseAuthStore.currentUserID)
                            await supabaseAuthStore.start()
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            guard !isRunningInPreview else { return }
                            supabaseAuthStore.handleScenePhase(newPhase)
                            guard newPhase == .active else { return }
                            Task {
                                await NotificationManager.shared.refreshAuthorizationStatus()
                                NotificationManager.shared.scheduleRefresh()
                                await SyncCoordinator.shared.refreshFromRemote(userID: supabaseAuthStore.currentUserID)
                            }
                        }
                }
            }
            .appBaseTypography()
            .environmentObject(supabaseAuthStore)
            .onOpenURL { url in
                guard !isRunningInPreview else { return }
                Task {
                    await supabaseAuthStore.handleIncomingURL(url)
                }
            }
        }
        .modelContainer(sharedModelContainer)
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
        let fileManager = FileManager.default
        let applicationSupport: URL

        do {
            applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            applicationSupport = URL.applicationSupportDirectory
        }

        let fileName: String
        switch syncMode {
        case .deviceOnly, .syncEverywhere:
            fileName = "default.store"
        case .iCloud:
            fileName = "icloud.store"
        }

        return applicationSupport.appending(path: fileName)
    }

    private static func ensureStoreDirectoryExists(for storeURL: URL) {
        let fileManager = FileManager.default
        let directoryURL = storeURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
            var didChange = false

            for tag in tags {
                let normalizedName = Tag.normalizeName(tag.name)

                guard !normalizedName.isEmpty else {
                    for toDo in toDos {
                        let remainingTags = toDo.effectiveTags.filter { $0.id != tag.id }
                        if remainingTags.count != toDo.effectiveTags.count {
                            toDo.setSelectedTags(remainingTags)
                            didChange = true
                        }
                    }

                    for nanoDo in nanoDos where nanoDo.tag?.id == tag.id {
                        nanoDo.tag = nil
                        didChange = true
                    }

                    context.delete(tag)
                    didChange = true
                    continue
                }

                if let canonicalTag = canonicalTagsByName[normalizedName], canonicalTag.id != tag.id {
                    for toDo in toDos {
                        let effectiveTags = toDo.effectiveTags
                        guard effectiveTags.contains(where: { $0.id == tag.id }) else { continue }

                        let mergedTags = effectiveTags.map { currentTag in
                            currentTag.id == tag.id ? canonicalTag : currentTag
                        }
                        toDo.setSelectedTags(mergedTags)
                        didChange = true
                    }

                    for nanoDo in nanoDos where nanoDo.tag?.id == tag.id {
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
            print("Failed to normalize stored tags: \(error)")
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
            print("Failed to normalize ToDo lifecycle states: \(error)")
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
            print("Failed to normalize ToDo reminder intents: \(error)")
            return false
        }
    }
}

private struct PreviewBootstrapView: View {
    var body: some View {
        Color.clear
    }
}
