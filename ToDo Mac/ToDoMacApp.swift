import SwiftData
import SwiftUI

@main
struct ToDoMacApp: App {
    @AppStorage("appAppearanceMode") private var appAppearanceModeRaw = ToDoMacAppearanceMode.system.rawValue
    @StateObject private var authStore = ToDoMacAuthStore.shared

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema([ToDo.self, Tag.self, NanoDo.self, SyncConflict.self])
            let configuration = ModelConfiguration("ToDoMac", schema: schema)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to start toDo for Mac: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup("toDō", id: "todo-mac-main") {
            ToDoMacWindowView()
                .modelContainer(modelContainer)
                .environmentObject(authStore)
                .frame(minWidth: 880, minHeight: 620)
                .appHapticFeedbackHost()
                .macAccessibilityAdaptations()
                .preferredColorScheme(preferredAppColorScheme)
                .task {
                    configurePlatformServices()
                    await authStore.start()
                }
                .onOpenURL { url in
                    Task { await authStore.handleIncomingURL(url) }
                }
        }
        .defaultSize(width: 980, height: 700)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            ToDoMacMenuView()
                .modelContainer(modelContainer)
                .environmentObject(authStore)
                .appHapticFeedbackHost()
                .macAccessibilityAdaptations()
                .preferredColorScheme(preferredAppColorScheme)
                .task {
                    configurePlatformServices()
                    await authStore.start()
                }
                .onOpenURL { url in
                    Task { await authStore.handleIncomingURL(url) }
                }
        } label: {
            Label("toDō", systemImage: "checkmark.circle.fill")
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
        SyncCoordinator.shared.configure(
            modelContainer: modelContainer,
            configuredSyncMode: AppPreferences.preferredSyncMode()
        )
        NotificationManager.shared.configure(modelContainer: modelContainer)
        WidgetSnapshotService.shared.writeSnapshot(from: modelContainer)
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
