import AppIntents
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
private enum ToDoMacPlatformBootstrap {
    static var didConfigure = false
}

private enum ToDoMacStoreRecovery {
    static let isActiveKey = "todo.storeRecovery.isActive"

    static func recordFailure() {
        UserDefaults.standard.set(true, forKey: isActiveKey)
    }

    static func clearFailure() {
        UserDefaults.standard.removeObject(forKey: isActiveKey)
    }
}

private struct ToDoMacStoreRecoveryNotice: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(ToDoMacStoreRecovery.isActiveKey) private var isActive = false

    var body: some View {
        if isActive {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.todoMacSymbol(18, weight: .bold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved data unavailable")
                        .font(.todoMacBodyStrong(15, relativeTo: .headline))
                    Text("toDō is using a temporary offline store. Close and reopen the app after checking storage or iCloud, then try again.")
                        .font(.todoMacBody(13, relativeTo: .footnote))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button("Continue offline") {
                    ToDoMacStoreRecovery.clearFailure()
                    isActive = false
                }
                .font(.todoMacBodyStrong(13, relativeTo: .footnote))
                .buttonStyle(.borderedProminent)
                .tint(ToDoMacPalette.brandYellow)
                .foregroundStyle(colorScheme == .dark ? .black : .white)
                .accessibilityHint("Dismisses this notice while keeping the temporary offline store active.")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundStyle(colorScheme == .dark ? .white : ToDoMacPalette.ink)
            .background(ToDoMacPalette.urgent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(10)
        }
    }
}

@main
struct ToDoMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAppearanceMode") private var appAppearanceModeRaw = ToDoMacAppearanceMode.system.rawValue
    @State private var showDockIconAtLaunch: Bool
    @State private var showMenuBarExtraAtLaunch: Bool
    @StateObject private var authStore = ToDoMacAuthStore.shared
    @StateObject private var purchaseManager = ToDoPurchaseManager.shared
    @StateObject private var collaborationService = ToDoCollaborationService.shared
    @StateObject private var menuState = ToDoMacMenuState.shared
    @StateObject private var connectivityMonitor = ToDoConnectivityMonitor.shared
    @State private var isRefreshingAccountSync = false
    @State private var accountSyncNeedsAnotherPass = false

    private let modelContainer: ModelContainer

    @MainActor
    init() {
        AppPreferences.registerDefaults()
        let storedDockPreference = UserDefaults.standard.object(forKey: ToDoMacPreferenceKeys.showDockIcon) as? Bool
        let storedMenuBarPreference = UserDefaults.standard.object(forKey: ToDoMacPreferenceKeys.showMenuBarExtra) as? Bool
        let resolvedDockPreference = storedDockPreference ?? true
        let resolvedMenuBarPreference = storedMenuBarPreference ?? true
        _showDockIconAtLaunch = State(initialValue: resolvedDockPreference)
        UserDefaults.standard.set(resolvedDockPreference, forKey: ToDoMacPreferenceKeys.appliedDockIconAtLaunch)
        UserDefaults.standard.set(resolvedMenuBarPreference, forKey: ToDoMacPreferenceKeys.appliedMenuBarExtraAtLaunch)
        _showMenuBarExtraAtLaunch = State(initialValue: resolvedMenuBarPreference)
        let container = Self.makeModelContainer()
        modelContainer = container
        let intentRepository = MainActor.assumeIsolated {
            ToDoIntentRepository(modelContainer: container)
        }
        AppDependencyManager.shared.add(dependency: intentRepository)
        ToDoShortcutsProvider.updateAppShortcutParameters()
    }

    @MainActor
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([ToDo.self, Tag.self, NanoDo.self, SyncConflict.self])
        let configuration = ModelConfiguration("ToDoMac", schema: schema)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            ToDoMacStoreRecovery.clearFailure()
            return container
        } catch {
            AppLog.error("Mac persistent store unavailable; using temporary offline store: \(error)", logger: AppLog.app)
            ToDoMacStoreRecovery.recordFailure()

            do {
                let recoveryConfiguration = ModelConfiguration(
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                return try ModelContainer(for: schema, configurations: [recoveryConfiguration])
            } catch {
                AppLog.error("Mac recovery store could not be initialized: \(error)", logger: AppLog.app)
                preconditionFailure("Unable to initialize the Mac recovery store.")
            }
        }
    }

    var body: some Scene {
        Window("toDō", id: "todo-mac-main") {
            ToDoMacWindowView()
                .overlay(alignment: .top) {
                    ToDoMacStoreRecoveryNotice()
                }
                .modelContainer(modelContainer)
                .environmentObject(authStore)
                .environmentObject(purchaseManager)
                .environmentObject(collaborationService)
                .environmentObject(menuState)
                .environmentObject(connectivityMonitor)
                .frame(
                    minWidth: AppAdaptiveLayout.macMinimumWindowWidth,
                    idealWidth: AppAdaptiveLayout.macIdealWindowWidth,
                    maxWidth: AppAdaptiveLayout.macMaximumWindowWidth,
                    minHeight: AppAdaptiveLayout.macMinimumWindowHeight,
                    idealHeight: AppAdaptiveLayout.macIdealWindowHeight,
                    maxHeight: AppAdaptiveLayout.macMaximumWindowHeight
                )
                .appHapticFeedbackHost()
                .macAccessibilityAdaptations()
                .preferredColorScheme(preferredAppColorScheme)
                .task {
                    configurePlatformServices()
                    applyDockIconPreference()
                    await authStore.start()
                    await purchaseManager.start(account: authStore.commerceAccount)
                    await collaborationService.updateAccount(authStore.commerceAccount)
                    await refreshAccountSyncIfNeeded()
                    NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await refreshAccountSyncIfNeeded()
                    }
                }
                .onChange(of: authStore.commerceAccount) { _, account in
                    Task {
                        await purchaseManager.updateAccount(account)
                        await collaborationService.updateAccount(account)
                    }
                }
                .onChange(of: authStore.scopedOwnerUserID) { _, _ in
                    NotificationManager.shared.scheduleRefresh()
                    NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
                }
                .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationMembershipDidChange)) { notification in
                    guard let userID = authStore.currentUserID else { return }
                    if let eventUserID = notification.object as? UUID, eventUserID != userID {
                        return
                    }
                    Task {
                        await SyncCoordinator.shared.refreshFromRemote(userID: userID)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .toDoCollaborationInvitationReceived)) { _ in
                    guard authStore.currentUserID != nil else { return }
                    Task {
                        await collaborationService.refresh()
                    }
                }
                .onOpenURL { url in
                    if collaborationService.receiveInvitationURL(url) {
                        return
                    }
                    Task { await authStore.handleIncomingURL(url) }
                }
        }
        .defaultSize(
            width: AppAdaptiveLayout.macIdealWindowWidth,
            height: AppAdaptiveLayout.macIdealWindowHeight
        )
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appSettings) { }
        }
        #endif

        MenuBarExtra("toDō", systemImage: "checkmark.circle.fill", isInserted: $showMenuBarExtraAtLaunch) {
            ToDoMacMenuView(modelContainer: modelContainer)
                .modelContainer(modelContainer)
                .environmentObject(authStore)
                .environmentObject(purchaseManager)
                .environmentObject(collaborationService)
                .environmentObject(menuState)
                .environmentObject(connectivityMonitor)
                .appHapticFeedbackHost()
                .macAccessibilityAdaptations()
                .preferredColorScheme(preferredAppColorScheme)
                .task {
                    configurePlatformServices()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private var preferredAppColorScheme: ColorScheme? {
        switch ToDoMacAppearanceMode(rawValue: appAppearanceModeRaw) ?? .system {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    @MainActor
    private func configurePlatformServices() {
        guard !ToDoMacPlatformBootstrap.didConfigure else { return }
        ToDoMacPlatformBootstrap.didConfigure = true

        SyncCoordinator.shared.configure(
            modelContainer: modelContainer,
            configuredSyncMode: AppPreferences.preferredSyncMode()
        )
        NotificationManager.shared.configure(
            modelContainer: modelContainer,
            currentUserIDProvider: {
                ToDoMacAuthStore.shared.scopedOwnerUserID
            },
            accessibleCollabIDsProvider: {
                Set(ToDoCollaborationService.shared.collabs.map(\.id))
            }
        )
    }

    @MainActor
    private func applyDockIconPreference() {
        #if os(macOS)
        NSApp.setActivationPolicy(showDockIconAtLaunch ? .regular : .accessory)
        #endif
    }

    @MainActor
    private func refreshAccountSyncIfNeeded() async {
        guard !isRefreshingAccountSync else {
            accountSyncNeedsAnotherPass = true
            return
        }
        isRefreshingAccountSync = true
        defer {
            isRefreshingAccountSync = false
            if accountSyncNeedsAnotherPass {
                accountSyncNeedsAnotherPass = false
                Task { await refreshAccountSyncIfNeeded() }
            }
        }

        await authStore.start()
        if authStore.currentUserID != nil {
            // Re-read the profile when the Mac returns to the foreground so a
            // remote avatar update reaches Home, Account, and collaboration UI.
            await authStore.refreshProfile()
        }
        let userID = authStore.currentUserID
        await SyncCoordinator.shared.applyPreferredSyncMode(userID: userID)
        guard SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere,
              let userID,
              authStore.currentUserID == userID else {
            return
        }

        await SupabaseSyncService.shared.resumeRealtimeIfNeeded()
        await SyncCoordinator.shared.flushLocalSync(userID: userID)
        NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
    }
}

private extension View {
    func macAccessibilityAdaptations() -> some View {
        modifier(MacAccessibilityAdaptationsModifier())
    }
}

private struct MacAccessibilityAdaptationsModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                if reduceMotion {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}
