import Combine
import CoreLocation
import MapKit
import OSLog
import SwiftData
import StoreKit
import SwiftUI
import UserNotifications

#if os(macOS)
import AppKit
#endif

enum ToDoMacPalette {
    static let ink = Color("appTextPrimary")
    static let mutedInk = Color("appTextSecondary")
    static let background = Color("appSurface")
    static let panel = Color("appSurfaceElevated")
    static let raised = Color("appSurfaceMuted")
    static let brandYellow = Color("appBrandMain")
    static let brandBlue = Color("appBrandSecondary")
    static let urgent = Color("appBrandDestructive")
    static let done = Color("appBrandTertiary")

    static func actionForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
}

private let macMenuLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "dev.iamshift.toDo",
    category: "MacMenu"
)

enum ToDoMacPreferenceKeys {
    static let appliedDockIconAtLaunch = "todo.mac.appliedDockIconAtLaunch"
    static let appliedMenuBarExtraAtLaunch = "todo.mac.appliedMenuBarExtraAtLaunch"
    static let appAppearanceMode = "appAppearanceMode"
    static let doneSwipePrimaryAction = "doneSwipePrimaryAction"
    // Versioned because the original payload did not retain account scope and
    // could briefly expose a previous account's rows after sign-out.
    static let menuSnapshot = "todo.mac.menuSnapshot.v2"
    static let pendingOpenToDoID = "todo.mac.pendingOpenToDoID"
    static let showDockIcon = "todo.mac.showDockIcon"
    static let showMenuBarExtra = "todo.mac.showMenuBarExtra"
    static let syncMode = "syncMode"
}

enum ToDoMacAppearanceMode: String {
    case system
    case light
    case dark
}

extension Notification.Name {
    static let toDoMacOpenAllToDos = Notification.Name("toDoMacOpenAllToDos")
    static let toDoMacOpenPendingToDo = Notification.Name("toDoMacOpenPendingToDo")
    static let toDoMacRefreshMenuToDos = Notification.Name("toDoMacRefreshMenuToDos")
}

@MainActor
final class ToDoMacMenuState: ObservableObject {
    static let shared = ToDoMacMenuState()

    @Published private(set) var items: [ToDoMacMenuItem] = []

    private init() {}

    func update(toDos: [ToDo]) {
        update(items: toDos.map(ToDoMacMenuItem.init))
    }

    func update(items newItems: [ToDoMacMenuItem]) {
        items = newItems
        persist(newItems)
    }

    @discardableResult
    func loadPersistedSnapshot() -> [ToDoMacMenuItem] {
        guard let data = UserDefaults.standard.data(forKey: ToDoMacPreferenceKeys.menuSnapshot) else {
            return []
        }

        do {
            let persistedItems = try JSONDecoder().decode([ToDoMacMenuItem].self, from: data)
            if !persistedItems.isEmpty {
                items = persistedItems
            }
            return persistedItems
        } catch {
            macMenuLog.error("Mac menu snapshot decode failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    private func persist(_ items: [ToDoMacMenuItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: ToDoMacPreferenceKeys.menuSnapshot)
        } catch {
            macMenuLog.error("Mac menu snapshot encode failed: \(String(describing: error), privacy: .public)")
        }
    }
}

struct ToDoMacMenuItem: Identifiable, Equatable, Codable {
    let id: String
    let task: String
    let dueDate: Date?
    let reminderIntent: ToDoReminderIntent
    let lifecycleState: ToDoState
    let updatedAt: Date?
    let createdAt: Date
    let ownerUserID: UUID?
    let collabID: UUID?

    init(toDo: ToDo) {
        id = String(describing: toDo.id)
        task = toDo.task
        dueDate = toDo.dueDate
        reminderIntent = toDo.reminderIntent
        lifecycleState = toDo.lifecycleState
        updatedAt = toDo.updatedAt
        createdAt = toDo.createdAt
        ownerUserID = toDo.ownerUserID
        collabID = toDo.collabID
    }
}

#if os(macOS)
@MainActor
private enum ToDoMacWindowPresenter {
    static func bringMainWindowForward() {
        Task { @MainActor in
            for delay in [60, 180, 360, 620] {
                try? await Task.sleep(for: .milliseconds(delay))
                activateMainWindow()
            }
        }
    }

    private static func activateMainWindow() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        NSApp.unhide(nil)

        guard let mainWindow = candidateMainWindow else { return }
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.collectionBehavior.remove(.transient)
        mainWindow.orderFrontRegardless()
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static var candidateMainWindow: NSWindow? {
        NSApp.windows.first { window in
            window.title == "toDō" && window.level == .normal
        } ?? NSApp.windows.first { window in
            window.level == .normal &&
                window.canBecomeKey &&
                !window.isSheet &&
                !window.className.localizedCaseInsensitiveContains("status")
        }
    }
}
#endif

extension Font {
    static func todoMacBrand(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .largeTitle
    ) -> Font {
        .custom("CalSans-Regular", size: size, relativeTo: textStyle)
    }

    static func todoMacDisplay(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .title2
    ) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
    }

    static func todoMacUI(
        _ size: CGFloat,
        weight: Font.Weight = .semibold,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Jura", size: size, relativeTo: textStyle).weight(weight)
    }

    static func todoMacEntry(
        _ size: CGFloat,
        weight: Font.Weight = .medium,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Aleo", size: size, relativeTo: textStyle).weight(weight)
    }

    // Keep these roles aligned with AppTypography rather than creating a Mac-only hierarchy.
    static func todoMacViewTitle(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .largeTitle
    ) -> Font {
        .custom("Cal Sans UI", size: size, relativeTo: textStyle).weight(.bold)
    }

    static func todoMacBody(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Jura", size: size, relativeTo: textStyle).weight(.regular)
    }

    static func todoMacBodyStrong(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Jura", size: size, relativeTo: textStyle).weight(.semibold)
    }

    static func todoMacHeadline(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .headline
    ) -> Font {
        .custom("Jura", size: size, relativeTo: textStyle).weight(.semibold)
    }

    static func todoMacBadge(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .caption
    ) -> Font {
        .custom("Jura", size: size, relativeTo: textStyle).weight(.bold)
    }

    static func todoMacLongForm(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Aleo", size: size, relativeTo: textStyle).weight(.regular).italic()
    }

    // System fonts are reserved here for SF Symbols and intentionally
    // monospaced release-history/code values; customer-facing prose uses the
    // shared app roles above.
    static func todoMacSymbol(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }

    static func todoMacCode(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private struct ToDoMacIconBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let color: Color
    var size: CGFloat = 14
    var dimension: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.todoMacSymbol(size, weight: .heavy))
            .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
            .frame(width: dimension, height: dimension)
            .background(color, in: Circle())
    }
}

private struct ToDoMacSectionHeader: View {
    let title: String
    var tint: Color = ToDoMacPalette.brandYellow

    var body: some View {
        Text(title)
            .font(.todoMacDisplay(30))
            .tracking(0.6)
            .foregroundStyle(ToDoMacPalette.ink)
    }
}

private enum ToDoMacTopLevelTitleStyle: Equatable {
    case brand
    case surface
}

private struct ToDoMacTopLevelHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var eyebrow: String?
    var titleStyle: ToDoMacTopLevelTitleStyle = .surface
    var onBack: (() -> Void)?
    var reservesBrandBackSlot = false
    var showsBrandBackButton = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.todoMacUI(14, weight: .heavy))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .tracking(0.5)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    // Keep every surface title on the same vertical track as the
                    // Home brand title. Only Home renders a real eyebrow value.
                    Color.clear
                        .frame(height: 17)
                }

                HStack(alignment: .center, spacing: 12) {
                    if titleStyle == .brand && reservesBrandBackSlot {
                        ZStack {
                            Color.clear
                                .frame(width: 32, height: 32)

                            if showsBrandBackButton, let onBack {
                                Button(action: onBack) {
                                    Image(systemName: "chevron.left")
                                        .font(.todoMacSymbol(18, weight: .heavy))
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(ToDoMacIconButtonStyle(
                                    color: ToDoMacPalette.brandYellow,
                                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                                ))
                                .accessibilityLabel("Back")
                                .transition(.move(edge: .leading))
                            }
                        }
                        .frame(width: 32, height: 32)
                    } else if titleStyle == .surface, let onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.todoMacSymbol(18, weight: .heavy))
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(ToDoMacIconButtonStyle(
                            color: ToDoMacPalette.brandYellow,
                            foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                        ))
                        .accessibilityLabel("Back")
                    }

                    titleView
                }
            }
            .frame(minHeight: 71, alignment: .bottom)
            .layoutPriority(1)

            Spacer(minLength: 0)
            trailing()
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 68, alignment: .center)
    }

    @ViewBuilder
    private var titleView: some View {
        switch titleStyle {
        case .brand:
            HStack(alignment: .center, spacing: 5) {
                Text(title)
                    .font(.todoMacBrand(50))
                    .foregroundStyle(ToDoMacPalette.ink)

                if title == "toDō" {
                    ToDoBrandPlusMark(
                        font: .todoMacBrand(35),
                        width: 28,
                        height: 38
                    )
                }
            }
        case .surface:
            Text(title)
                .font(.todoMacViewTitle(36))
                .foregroundStyle(ToDoMacPalette.ink)
        }
    }
}

struct ToDoMacMenuView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var menuState: ToDoMacMenuState
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    let modelContainer: ModelContainer
    @State private var menuItems: [ToDoMacMenuItem] = []
    @State private var completingToDoIDs = Set<String>()
    private let refreshTimer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()

    private var sourceItems: [ToDoMacMenuItem] {
        menuState.items.isEmpty ? menuItems : menuState.items
    }

    private var visibleSourceItems: [ToDoMacMenuItem] {
        let ownerUserID = authStore.scopedOwnerUserID
        let accessibleCollabIDs = Set(collaborationService.collabs.map(\.id))
        return sourceItems.filter {
            $0.lifecycleState == .active
                && (
                    $0.ownerUserID == ownerUserID
                        || $0.collabID.map(accessibleCollabIDs.contains) == true
                )
        }
    }

    private var visibleToDos: [ToDoMacMenuItem] {
        visibleSourceItems
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return (lhs.updatedAt ?? lhs.createdAt) > (rhs.updatedAt ?? rhs.createdAt)
                }
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            upcomingList
            footerActions
        }
        .padding(22)
        .frame(width: 390)
        .background(ToDoMacPalette.background)
        .onAppear {
            loadMenuSnapshot()
            refreshMenuToDos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacOpenAllToDos)) { _ in
            loadMenuSnapshot()
            refreshMenuToDos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacOpenPendingToDo)) { _ in
            loadMenuSnapshot()
            refreshMenuToDos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacRefreshMenuToDos)) { _ in
            loadMenuSnapshot()
            refreshMenuToDos()
        }
        .onReceive(refreshTimer) { _ in
            loadMenuSnapshot()
            refreshMenuToDos()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("toDō")
                .font(.todoMacBrand(34))
                .foregroundStyle(ToDoMacPalette.ink)
            Spacer()
        }
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("toDōs")
                .font(.todoMacDisplay(24))
                .tracking(0.7)
                .foregroundStyle(ToDoMacPalette.ink)

            if visibleToDos.isEmpty {
                Text("Nothing active right now.")
                    .font(.todoMacUI(13))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleToDos) { toDo in
                            ToDoMacCompactRow(
                                item: toDo,
                                isCompleting: completingToDoIDs.contains(toDo.id),
                                onOpen: { openToDo(toDo) },
                                onComplete: { complete(toDo) }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.985)),
                                removal: .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.94))
                            ))
                        }
                    }
                    .animation(menuAnimation, value: visibleToDos.map(\.id))
                    .animation(menuAnimation, value: completingToDoIDs)
                }
                .frame(height: listHeight)
                .scrollIndicators(.visible)
            }
        }
    }

    private var listHeight: CGFloat {
        min(max(CGFloat(visibleToDos.count) * 66, 76), 360)
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button {
                openAllToDos()
            } label: {
                Label("Open all toDōs", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        }
    }

    private func complete(_ item: ToDoMacMenuItem) {
        guard !completingToDoIDs.contains(item.id) else { return }
        _ = withAnimation(menuAnimation) {
            completingToDoIDs.insert(item.id)
        }

        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(520))
            }
            if let toDo = fetchToDo(matching: item) {
                toDo.transition(to: .done)
                try? modelContainer.mainContext.save()
            }
            completingToDoIDs.remove(item.id)
            refreshMenuToDos()
            refreshMacSurfaces()
        }
    }

    private func openAllToDos() {
        UserDefaults.standard.removeObject(forKey: ToDoMacPreferenceKeys.pendingOpenToDoID)
        openWindow(id: "todo-mac-main")
        NotificationCenter.default.post(name: .toDoMacOpenAllToDos, object: nil)
        #if os(macOS)
        ToDoMacWindowPresenter.bringMainWindowForward()
        #endif
    }

    private func openToDo(_ item: ToDoMacMenuItem) {
        UserDefaults.standard.set(item.id, forKey: ToDoMacPreferenceKeys.pendingOpenToDoID)
        openWindow(id: "todo-mac-main")
        NotificationCenter.default.post(name: .toDoMacOpenPendingToDo, object: nil)
        #if os(macOS)
        ToDoMacWindowPresenter.bringMainWindowForward()
        #endif
    }

    private func refreshMacSurfaces() {
        NotificationManager.shared.scheduleRefresh()
        SyncCoordinator.shared.scheduleLocalSync()
    }

    private func refreshMenuToDos() {
        var descriptor = FetchDescriptor<ToDo>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        do {
            let fetchedToDos = try modelContainer.mainContext.fetch(descriptor)
            let ownerUserID = authStore.scopedOwnerUserID
            let accessibleCollabIDs = Set(collaborationService.collabs.map(\.id))
            let fetchedItems = fetchedToDos
                .filter {
                    $0.ownerUserID == ownerUserID
                        || $0.collabID.map(accessibleCollabIDs.contains) == true
                }
                .map(ToDoMacMenuItem.init)
            menuItems = fetchedItems
            menuState.update(items: fetchedItems)
        } catch {
            macMenuLog.error("Mac menu container fetch failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func loadMenuSnapshot() {
        let persistedItems = menuState.loadPersistedSnapshot()
        if !persistedItems.isEmpty {
            menuItems = persistedItems
        }
    }

    private func fetchToDo(matching item: ToDoMacMenuItem) -> ToDo? {
        let scope = ToDoVisibilityScope(
            ownerUserID: authStore.scopedOwnerUserID,
            accessibleCollabIDs: Set(collaborationService.collabs.map(\.id))
        )
        let descriptor = FetchDescriptor<ToDo>()
        return (try? modelContainer.mainContext.fetch(descriptor))?
            .first {
                String(describing: $0.id) == item.id
                    && scope.includes(ownerUserID: $0.ownerUserID, collabID: $0.collabID)
                    && $0.ownerUserID == item.ownerUserID
                    && $0.collabID == item.collabID
            }
    }

    private var menuAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24)
    }
}

struct ToDoMacWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ToDo.createdAt, order: .reverse) private var storedToDos: [ToDo]
    @Query(sort: \Tag.name) private var storedTags: [Tag]
    @EnvironmentObject private var menuState: ToDoMacMenuState
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
    @AppStorage(ToDoMacPreferenceKeys.showDockIcon) private var showDockIcon = true
    @AppStorage(ToDoMacPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(ToDoMacPreferenceKeys.appliedDockIconAtLaunch) private var appliedDockIconAtLaunch = true
    @AppStorage(ToDoMacPreferenceKeys.appliedMenuBarExtraAtLaunch) private var appliedMenuBarExtraAtLaunch = true
    @AppStorage(AppPreferences.Keys.toDoListSortOption) private var toDoListSortOption = AppPreferences.ToDoListSortOption.dueDate.rawValue
    @AppStorage(AppPreferences.Keys.toDoListSortReversed) private var isToDoListSortReversed = false
    @State private var screen: ToDoMacScreen = .home
    @State private var screenNavigationDirection: AppNavigationDirection = .forward
    @State private var detailNavigationDirection: AppNavigationDirection = .forward
    @State private var selectedToDoIdentity: ToDoSelectionIdentity?
    @State private var editorMode: ToDoMacEditorMode?
    @State private var presentationNotice: ToDoMacPresentationNotice?
    @State private var presentationNoticeTask: Task<Void, Never>?
    @State private var didRequestInitialDataLoad = false
    @State private var isMacUtilityTrayVisible = false
    @State private var macSearchText = ""
    @State private var macListFilter: ToDoMacListFilter = .all
    @State private var macHomeFilter: ToDoMacHomeFilter = .recent
    @State private var viewportWidth: CGFloat = 0
    @State private var isShowingProfile = false
    @State private var toDosHeaderTitleShifted = false
    @State private var toDosHeaderBackVisible = false

    private var toDos: [ToDo] {
        let ownerUserID = authStore.scopedOwnerUserID
        let accessibleCollabIDs = Set(collaborationService.collabs.map(\.id))

        let scoped = storedToDos.filter {
            $0.ownerUserID == ownerUserID
                || $0.collabID.map(accessibleCollabIDs.contains) == true
        }
        return ToDo.canonicalToDos(from: scoped)
    }

    private var tags: [Tag] {
        let ownerUserID = authStore.scopedOwnerUserID
        let visibleTagIDs = Set(toDos.flatMap { $0.effectiveTags.map(\.id) })

        return Tag.canonicalTags(from: storedTags.filter {
            $0.ownerUserID == ownerUserID || visibleTagIDs.contains($0.id)
        })
    }

    private var selectedToDo: ToDo? {
        ToDo.resolveSelection(selectedToDoIdentity, from: toDos)
    }

    private var editingToDo: ToDo? {
        guard let identity = editorMode?.existingIdentity else { return nil }
        return ToDo.resolveSelection(identity, from: toDos)
    }

    private var hasFocusedPane: Bool {
        screen == .allToDos && selectedToDo != nil
    }

    private var adaptiveMetrics: ToDoMacAdaptiveMetrics {
        ToDoMacAdaptiveMetrics(viewportWidth: viewportWidth > 0 ? viewportWidth : 980)
    }

    private var activeToDos: [ToDo] {
        toDos.filter { $0.lifecycleState == .active }
    }

    private var filteredActiveToDos: [ToDo] {
        let now = Date()
        let dueSoonCutoff = ToDo.dueSoonUpperBound(from: now)
        let search = macSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let filtered = activeToDos
            .filter { toDo in
                switch macListFilter {
                case .all:
                    return true
                case .dueSoon:
                    guard let dueDate = toDo.dueDate else { return false }
                    return dueDate >= now && dueDate <= dueSoonCutoff
                case .timeSensitive:
                    return toDo.reminderIntent == .timeSensitive
                case .overdue:
                    guard let dueDate = toDo.dueDate else { return false }
                    return dueDate < now
                }
            }
            .filter { toDo in
                guard !search.isEmpty else { return true }
                if toDo.task.localizedLowercase.contains(search) { return true }
                if toDo.notes.localizedLowercase.contains(search) { return true }
                if toDo.effectiveTags.contains(where: { $0.displayName.localizedLowercase.contains(search) }) { return true }
                return toDo.nanoDos.contains { $0.task.localizedLowercase.contains(search) }
            }
        return sortedMacToDos(filtered)
    }

    private var macSortOption: AppPreferences.ToDoListSortOption {
        AppPreferences.ToDoListSortOption(rawValue: toDoListSortOption) ?? .dueDate
    }

    private func sortedMacToDos(_ toDos: [ToDo]) -> [ToDo] {
        let sorted: [ToDo]
        switch macSortOption {
        case .dueDate:
            sorted = toDos.sorted(by: macDueDateSort)
        case .creationDate:
            sorted = toDos.sorted { lhs, rhs in
                if lhs.isLate != rhs.isLate {
                    return lhs.isLate && !rhs.isLate
                }
                return lhs.createdAt > rhs.createdAt
            }
        case .tag:
            sorted = toDos.sorted { lhs, rhs in
                let leftTag = lhs.effectiveTags.first?.name ?? ""
                let rightTag = rhs.effectiveTags.first?.name ?? ""
                if leftTag == rightTag {
                    if lhs.isLate != rhs.isLate {
                        return lhs.isLate && !rhs.isLate
                    }
                    return lhs.createdAt > rhs.createdAt
                }
                return leftTag.localizedCaseInsensitiveCompare(rightTag) == .orderedAscending
            }
        case .dueMonthSections:
            let calendar = AppLocalization.displayCalendar
            sorted = toDos.sorted { lhs, rhs in
                let leftMonth = lhs.dueDate.flatMap {
                    calendar.date(from: calendar.dateComponents([.year, .month], from: $0))
                } ?? .distantFuture
                let rightMonth = rhs.dueDate.flatMap {
                    calendar.date(from: calendar.dateComponents([.year, .month], from: $0))
                } ?? .distantFuture
                return leftMonth == rightMonth ? macDueDateSort(lhs, rhs) : leftMonth < rightMonth
            }
        case .tagSections:
            sorted = toDos.sorted { lhs, rhs in
                let leftTag = lhs.effectiveTags.first?.displayName
                let rightTag = rhs.effectiveTags.first?.displayName
                switch (leftTag, rightTag) {
                case let (left?, right?) where left != right:
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return macDueDateSort(lhs, rhs)
                }
            }
        case .nanoDoSections:
            sorted = toDos.sorted { lhs, rhs in
                if lhs.nanoDos.count != rhs.nanoDos.count {
                    return lhs.nanoDos.count > rhs.nanoDos.count
                }
                return macDueDateSort(lhs, rhs)
            }
        }

        return isToDoListSortReversed ? Array(sorted.reversed()) : sorted
    }

    private func macDueDateSort(_ lhs: ToDo, _ rhs: ToDo) -> Bool {
        ToDo.presentationDueDateSort(lhs, rhs)
    }

    private var hasPendingIconRestart: Bool {
        showDockIcon != appliedDockIconAtLaunch || showMenuBarExtra != appliedMenuBarExtraAtLaunch
    }

    private var dueSoon: [ToDo] {
        ToDo.dueSoon(from: activeToDos)
    }

    private var homePreviewToDos: [ToDo] {
        switch macHomeFilter {
        case .recent:
            return ToDo.recent(from: activeToDos)
        case .dueSoon:
            return dueSoon
        case .timeSensitive:
            return ToDo.timeSensitive(from: activeToDos)
        }
    }

    private func macDueSoonUpperBound(from now: Date) -> Date {
        ToDo.dueSoonUpperBound(from: now)
    }

    private var completedCount: Int {
        toDos.filter { $0.lifecycleState == .done }.count
    }

    private var overdueCount: Int {
        activeToDos.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return dueDate < .now
        }.count
    }

    private var timeSensitiveCount: Int {
        activeToDos.filter { $0.reminderIntent == .timeSensitive }.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            ToDoMacPalette.background
                .ignoresSafeArea()

            ToDoMacAdaptiveStage(
                metrics: adaptiveMetrics,
                screen: screen,
                hasFocusedPane: hasFocusedPane
            ) {
                ZStack {
                    topLevelShell
                        .allowsHitTesting(editorMode == nil)
                        .accessibilityHidden(editorMode != nil)

                    if editorMode != nil {
                        standaloneEditorPane
                            .transition(macSidePaneTransition)
                            .zIndex(2)
                    }
                }
                .animation(macTransitionAnimation, value: editorMode?.id)
            }

            if let presentationNotice {
                ToDoMacTransientNotice(message: presentationNotice.message)
                    .padding(.top, adaptiveMetrics.verticalPadding + 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { viewportWidth = $0 }
        .containerBackground(ToDoMacPalette.background, for: .window)
        .ignoresSafeArea()
        .task {
            await requestInitialMacDataLoadIfNeeded()
        }
        .onChange(of: menuStateSignature) { _, _ in
            publishMenuState()
            reconcileFocusedToDo()
        }
        .onChange(of: collaborationService.collabs.map(\.id)) { _, _ in
            reloadMacData()
            reconcileFocusedToDo()
        }
        .onChange(of: authStore.currentUserID) { _, _ in
            selectedToDoIdentity = nil
            editorMode = nil
            presentationNoticeTask?.cancel()
            presentationNotice = nil
            reloadMacData(refreshRemote: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacOpenAllToDos)) { _ in
            resetMacListScope()
            selectedToDoIdentity = nil
            editorMode = nil
            navigate(to: .allToDos, direction: .forward)
            #if os(macOS)
            ToDoMacWindowPresenter.bringMainWindowForward()
            #endif
            reloadMacData(refreshRemote: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacOpenPendingToDo)) { _ in
            reloadMacData(openPendingToDo: true, refreshRemote: true)
            #if os(macOS)
            ToDoMacWindowPresenter.bringMainWindowForward()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .toDoMacRefreshMenuToDos)) { _ in
            reloadMacData()
        }
        .onDisappear {
            presentationNoticeTask?.cancel()
        }
        .sheet(isPresented: $isShowingProfile, onDismiss: {
            Task { await authStore.refreshProfile() }
        }) {
            ToDoMacProfileSheet()
                .frame(
                    minWidth: 620,
                    idealWidth: 720,
                    maxWidth: nil,
                    minHeight: 620,
                    idealHeight: 760,
                    maxHeight: nil
                )
        }
        .sheet(isPresented: Binding(
            get: { collaborationService.pendingInvitationID != nil },
            set: { isPresented in
                if !isPresented {
                    collaborationService.clearPendingInvitation()
                }
            }
        )) {
            if let invitationID = collaborationService.pendingInvitationID {
                ToDoMacCollabInvitationReviewView(invitationID: invitationID) {
                    collaborationService.clearPendingInvitation()
                }
            }
        }
    }

    private var macTransitionAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24)
    }

    private var usesWideMacSplit: Bool {
        adaptiveMetrics.usesWideSplit
    }

    private func navigate(to destination: ToDoMacScreen, direction: AppNavigationDirection) {
        guard screen != destination else { return }

        if destination == .allToDos {
            enterToDos()
            return
        }

        if screen == .allToDos, destination == .home {
            leaveToDos()
            return
        }

        screenNavigationDirection = direction
        guard !reduceMotion else {
            var transaction = Transaction()
            transaction.animation = nil
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                screen = destination
            }
            return
        }

        // Change the screen and let the native asymmetric transition animate
        // the source out and destination in within one transaction.
        withAnimation(macTransitionAnimation) {
            screen = destination
        }
    }

    private func enterToDos(selecting selection: ToDoSelectionIdentity? = nil) {
        screenNavigationDirection = .forward

        if reduceMotion {
            withAnimation(nil) {
                screen = .allToDos
                selectedToDoIdentity = selection
                toDosHeaderTitleShifted = true
                toDosHeaderBackVisible = true
            }
            return
        }

        withAnimation(macTransitionAnimation) {
            screen = .allToDos
            selectedToDoIdentity = selection
            toDosHeaderTitleShifted = true
            toDosHeaderBackVisible = true
        }
    }

    private func openCreateEditor() {
        detailNavigationDirection = .forward
        withAnimation(macTransitionAnimation) {
            selectedToDoIdentity = nil
            editorMode = .create()
        }
    }

    private func openFocusedToDo(_ toDo: ToDo) {
        detailNavigationDirection = .forward
        withAnimation(macTransitionAnimation) {
            editorMode = nil
            selectedToDoIdentity = toDo.selectionIdentity
        }
    }

    private func closeFocusedToDo() {
        detailNavigationDirection = .backward
        withAnimation(macTransitionAnimation) {
            selectedToDoIdentity = nil
        }
    }

    private func closeEditor() {
        detailNavigationDirection = .backward
        withAnimation(macTransitionAnimation) {
            editorMode = nil
        }
    }

    private func leaveToDos() {
        guard !reduceMotion else {
            withAnimation(nil) {
                selectedToDoIdentity = nil
                editorMode = nil
                screen = .home
                toDosHeaderBackVisible = false
                toDosHeaderTitleShifted = false
            }
            return
        }

        screenNavigationDirection = .backward
        withAnimation(macTransitionAnimation) {
            screen = .home
            selectedToDoIdentity = nil
            editorMode = nil
            toDosHeaderTitleShifted = false
            toDosHeaderBackVisible = false
        }
    }

    private func reconcileFocusedToDo() {
        let selectionWasRemoved = selectedToDoIdentity != nil && selectedToDo == nil
        let editedRecordWasRemoved = editorMode?.existingIdentity != nil && editingToDo == nil
        guard selectionWasRemoved || editedRecordWasRemoved else { return }

        detailNavigationDirection = .backward
        withAnimation(macTransitionAnimation) {
            if selectionWasRemoved {
                selectedToDoIdentity = nil
            }
            if editedRecordWasRemoved {
                editorMode = nil
            }
        }
        showPresentationNotice(String(localized: "toDō removed on another device."))
    }

    private func showPresentationNotice(_ message: String) {
        presentationNoticeTask?.cancel()
        let notice = ToDoMacPresentationNotice(message: message)
        withAnimation(macTransitionAnimation) {
            presentationNotice = notice
        }
        presentationNoticeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, presentationNotice?.id == notice.id else { return }
            withAnimation(macTransitionAnimation) {
                presentationNotice = nil
            }
        }
    }

    private var menuStateSignature: [String] {
        toDos.map { toDo in
            [
                String(describing: toDo.id),
                toDo.lifecycleStateRaw,
                toDo.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
                toDo.dueDate?.timeIntervalSinceReferenceDate.description ?? "",
                toDo.task
            ].joined(separator: "|")
        }
    }

    private func publishMenuState() {
        menuState.update(toDos: toDos)
    }

    private func requestInitialMacDataLoadIfNeeded() async {
        guard !didRequestInitialDataLoad else { return }
        didRequestInitialDataLoad = true
        try? await Task.sleep(for: .milliseconds(250))
        await loadMacData(openPendingToDo: true, refreshRemote: true)
    }

    private func reloadMacData(openPendingToDo: Bool = false, refreshRemote: Bool = false) {
        Task { @MainActor in
            await loadMacData(openPendingToDo: openPendingToDo, refreshRemote: refreshRemote)
        }
    }

    private func loadMacData(openPendingToDo: Bool = false, refreshRemote: Bool = false) async {
        if refreshRemote, SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere {
            await SyncCoordinator.shared.refreshFromRemote(userID: authStore.currentUserID)
        }

        await Task.yield()
        publishMenuState()
        if openPendingToDo {
            openPendingToDoIfNeeded()
        }
    }

    private func openPendingToDoIfNeeded() {
        guard let pendingID = UserDefaults.standard.string(forKey: ToDoMacPreferenceKeys.pendingOpenToDoID) else {
            return
        }
        guard let toDo = toDos.first(where: { String(describing: $0.id) == pendingID }) else {
            return
        }
        UserDefaults.standard.removeObject(forKey: ToDoMacPreferenceKeys.pendingOpenToDoID)
        detailNavigationDirection = .forward
        editorMode = nil
        enterToDos(selecting: toDo.selectionIdentity)
    }

    private var macSidePaneTransition: AnyTransition {
        ToDoMacTransitionResolver.transition(
            direction: detailNavigationDirection,
            layer: .detail,
            reduceMotion: reduceMotion
        )
    }

    private var macScreenTransition: AnyTransition {
        ToDoMacTransitionResolver.transition(
            direction: screenNavigationDirection,
            layer: .screen,
            reduceMotion: reduceMotion
        )
    }

    private var topLevelShell: some View {
        VStack(alignment: .leading, spacing: 22) {
            topLevelHeader

            ZStack(alignment: .topLeading) {
                screenContent
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .clipped()
        }
    }

    @ViewBuilder
    private var topLevelHeader: some View {
        ToDoMacTopLevelHeader(
            title: topLevelTitle,
            eyebrow: screen == .home
                ? AppLocalization.dateString(.now).uppercased()
                : nil,
            titleStyle: topLevelTitleStyle,
            onBack: topLevelBackAction,
            reservesBrandBackSlot: screen == .allToDos || toDosHeaderTitleShifted,
            showsBrandBackButton: screen == .allToDos && toDosHeaderBackVisible
        ) {
            topLevelHeaderTrailing
        }
    }

    private var topLevelTitle: String {
        switch screen {
        case .home, .allToDos: return "toDō"
        case .settings: return "Settings"
        case .stats: return "Stats"
        }
    }

    private var topLevelTitleStyle: ToDoMacTopLevelTitleStyle {
        switch screen {
        case .home, .allToDos: return .brand
        case .settings, .stats: return .surface
        }
    }

    private var topLevelBackAction: (() -> Void)? {
        switch screen {
        case .home:
            return nil
        case .allToDos:
            return selectedToDo == nil ? leaveToDos : closeFocusedToDo
        case .settings, .stats:
            return { navigate(to: .home, direction: .backward) }
        }
    }

    @ViewBuilder
    private var topLevelHeaderTrailing: some View {
        switch screen {
        case .home:
            VStack(spacing: 8) {
                if authStore.isAuthenticated {
                    Button {
                        isShowingProfile = true
                    } label: {
                        ToDoMacProfileAvatar(
                            displayName: ToDoProfilePolicy.resolvedDisplayName(
                                profile: authStore.profile,
                                email: authStore.signedInEmail
                            ),
                            avatarURL: authStore.profile?.avatarURL,
                            size: 42,
                            localUserID: authStore.currentUserID,
                            localImageRevision: authStore.profileImageRevision
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open My Profile")
                    .accessibilityHint("Shows your profile and account details.")
                }

                Button {
                    navigate(to: .settings, direction: .forward)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.todoMacSymbol(18, weight: .heavy))
                            .frame(width: 46, height: 46)

                        if hasPendingIconRestart {
                            ToDoMacRestartTag()
                        }
                    }
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.brandYellow,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Open Settings")
            }
        case .allToDos:
            HStack(spacing: 12) {
                Button {
                    withAnimation(macTransitionAnimation) {
                        isMacUtilityTrayVisible.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.todoMacSymbol(20, weight: .heavy))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: isMacUtilityTrayVisible ? ToDoMacPalette.brandBlue : ToDoMacPalette.raised,
                    foreground: isMacUtilityTrayVisible ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.ink
                ))
                .accessibilityLabel(isMacUtilityTrayVisible ? "Hide utilities" : "Show utilities")

                Button(action: openCreateEditor) {
                    Image(systemName: "plus")
                        .font(.todoMacSymbol(22, weight: .heavy))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.brandYellow,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Create new toDō")
                .accessibilityHint("Opens the new toDō editor.")
            }
        case .settings, .stats:
            EmptyView()
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .home:
            homePane
                .transition(macScreenTransition)
        case .allToDos:
            if selectedToDo == nil {
                listPane
                    .transition(macScreenTransition)
            } else if !usesWideMacSplit {
                focusedMacDetailPane
                    .transition(macSidePaneTransition)
            } else {
                HStack(spacing: 22) {
                    listPane
                    focusedMacDetailPane
                        .transition(macSidePaneTransition)
                }
                .animation(macTransitionAnimation, value: selectedToDoIdentity)
                .transition(macScreenTransition)
            }
        case .settings:
            ToDoMacSettingsPane(
                toDos: toDos,
                onSkipAuthentication: {
                    navigate(to: .home, direction: .backward)
                }
            )
            .transition(macScreenTransition)
        case .stats:
            ToDoMacStatsPane(toDos: toDos)
            .transition(macScreenTransition)
        }
    }

    @ViewBuilder
    private var focusedMacDetailPane: some View {
        if let selectedToDo {
            ToDoMacDetailPane(
                toDo: selectedToDo,
                canRemove: canManageRemovalAction(for: selectedToDo),
                onEdit: {
                    detailNavigationDirection = .forward
                    withAnimation(macTransitionAnimation) {
                        editorMode = .edit(selectedToDo.selectionIdentity)
                    }
                },
                onComplete: { complete(selectedToDo) },
                onTrash: { trash(selectedToDo) },
                onClose: closeFocusedToDo
            )
            .id(selectedToDo.id)
        }
    }

    @ViewBuilder
    private var standaloneEditorPane: some View {
        if let editorMode, editorMode.existingIdentity == nil || editingToDo != nil {
            ZStack {
                ToDoMacPalette.background

                ToDoMacEditorPane(
                    mode: editorMode,
                    existingToDo: editingToDo,
                    availableTags: tags,
                    onCancel: closeEditor,
                    onSave: { savedToDo in
                        detailNavigationDirection = .backward
                        withAnimation(macTransitionAnimation) {
                            if editorMode.existingIdentity != nil {
                                selectedToDoIdentity = savedToDo.selectionIdentity
                            }
                            self.editorMode = nil
                        }
                        refreshMacSurfaces()
                        reloadMacData()
                    }
                )
                .id(editorMode.id)
                .frame(maxWidth: 860, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var homePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                homeHero
                homeUpNext
                homeMomentum
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var macHeader: some View {
        ToDoMacTopLevelHeader(
            title: "toDō",
            eyebrow: nil,
            titleStyle: .brand
        ) {
            Button {
                navigate(to: .settings, direction: .forward)
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.todoMacSymbol(18, weight: .heavy))
                        .frame(width: 46, height: 46)

                    if hasPendingIconRestart {
                        ToDoMacRestartTag()
                    }
                }
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        }
    }

    private var homeHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What matters now?")
                .font(.todoMacBodyStrong(25, relativeTo: .title2))
                .fontWeight(.black)
                .foregroundStyle(ToDoMacPalette.ink)

            if let bannerText = connectivityMonitor.bannerText {
                Text(bannerText)
                    .font(.todoMacUI(12, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ToDoMacPalette.urgent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    macNewToDoButton
                    macSeeAllToDosButton
                }

                VStack(spacing: 10) {
                    macNewToDoButton
                    macSeeAllToDosButton
                }
            }
        }
        .padding(22)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var macNewToDoButton: some View {
        Button {
            openCreateEditor()
        } label: {
            HStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.todoMacSymbol(17, weight: .bold))
                    .frame(width: 24, height: 24)

                Text("New toDō")
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        .accessibilityLabel("Create new toDō")
        .accessibilityHint("Opens the new toDō editor.")
    }

    private var macSeeAllToDosButton: some View {
        Button {
            resetMacListScope()
            selectedToDoIdentity = nil
            editorMode = nil
            navigate(to: .allToDos, direction: .forward)
        } label: {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("See all toDōs")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.todoMacSymbol(16, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        .accessibilityLabel("See all toDōs")
        .accessibilityHint("Opens the full toDō list.")
    }

    private var homeUpNext: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToDoMacSectionHeader(title: "Up Next")

            HStack(spacing: 8) {
                ForEach(ToDoMacHomeFilter.allCases) { filter in
                    Button {
                        withAnimation(macTransitionAnimation) {
                            macHomeFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                    }
                    .buttonStyle(ToDoMacFilterButtonStyle(
                        color: filter.color,
                        isSelected: macHomeFilter == filter
                    ))
                }
            }

            if homePreviewToDos.isEmpty {
                Text("Nothing needs the front row right now.")
                    .font(.todoMacUI(14))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if homePreviewToDos.count > 3 {
                ScrollView(.vertical) {
                    homePreviewRows
                }
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: homePreviewScrollHeight)
                .accessibilityLabel("Up next toDōs")
            } else {
                homePreviewRows
                    .accessibilityLabel("Up next toDōs")
            }
        }
        .animation(macTransitionAnimation, value: macHomeFilter)
        .animation(macTransitionAnimation, value: homePreviewToDos.map(\.persistentModelID))
    }

    private var homePreviewScrollHeight: CGFloat {
        // Keep three rows visible while making the scroll region proportional to
        // the actual row size instead of stretching to an arbitrary panel height.
        min(max(CGFloat(homePreviewToDos.count) * 72, 144), 224)
    }

    private var homePreviewRows: some View {
        LazyVStack(spacing: 10) {
            ForEach(homePreviewToDos) { toDo in
                ToDoMacHomeReadOnlyRow(toDo: toDo)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func resetMacListScope() {
        macListFilter = .all
        macSearchText = ""
        isMacUtilityTrayVisible = false
    }

    private var homeMomentum: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ToDoMacSectionHeader(title: "Momentum")
                Spacer()
                Button {
                    navigate(to: .stats, direction: .forward)
                } label: {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .accessibilityLabel("Open stats")
            }

            // Prefer one compact row when the window can support it. The fallback
            // keeps the cards content-sized instead of stretching each card to a
            // half-window column with an empty trailing area.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    homeMetric(title: "Active", value: activeToDos.count, color: ToDoMacPalette.brandBlue, icon: "bolt.fill")
                    homeMetric(title: "Due soon", value: dueSoon.count, color: ToDoMacPalette.brandYellow, icon: "clock.fill")
                    homeMetric(title: "Overdue", value: overdueCount, color: ToDoMacPalette.urgent, icon: "exclamationmark")
                    homeMetric(title: "Time-sensitive", value: timeSensitiveCount, color: ToDoMacPalette.urgent, icon: "flame.fill")
                    homeMetric(title: "Completed", value: completedCount, color: ToDoMacPalette.done, icon: "checkmark")
                }

                LazyVGrid(
                    columns: [
                        GridItem(.fixed(176), spacing: 12, alignment: .leading),
                        GridItem(.fixed(176), spacing: 12, alignment: .leading),
                        GridItem(.fixed(176), spacing: 12, alignment: .leading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    homeMetric(title: "Active", value: activeToDos.count, color: ToDoMacPalette.brandBlue, icon: "bolt.fill")
                    homeMetric(title: "Due soon", value: dueSoon.count, color: ToDoMacPalette.brandYellow, icon: "clock.fill")
                    homeMetric(title: "Overdue", value: overdueCount, color: ToDoMacPalette.urgent, icon: "exclamationmark")
                    homeMetric(title: "Time-sensitive", value: timeSensitiveCount, color: ToDoMacPalette.urgent, icon: "flame.fill")
                    homeMetric(title: "Completed", value: completedCount, color: ToDoMacPalette.done, icon: "checkmark")
                }
            }
        }
    }

    private func homeMetric(title: String, value: Int, color: Color, icon: String) -> some View {
        ToDoMacMetric(
            title: title,
            value: value,
            color: color,
            icon: icon,
            isCompact: true
        )
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            if isMacUtilityTrayVisible {
                macUtilityTray
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List {
                if !filteredActiveToDos.isEmpty {
                    Color.clear
                        .frame(height: 3)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityHidden(true)
                }

                if filteredActiveToDos.isEmpty {
                    macListEmptyState
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredActiveToDos) { toDo in
                        ToDoMacWindowRow(
                            toDo: toDo,
                            isSelected: selectedToDo?.id == toDo.id,
                            canRemove: canManageRemovalAction(for: toDo),
                            onSelect: {
                                openFocusedToDo(toDo)
                            },
                            onComplete: { complete(toDo) },
                            onTrash: { trash(toDo) }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }

            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                listSummaryFooter
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(ToDoMacPalette.background)
            }
        }
        .frame(
            minWidth: usesWideMacSplit && hasFocusedPane ? 420 : nil,
            maxWidth: usesWideMacSplit && hasFocusedPane ? 520 : .infinity,
            alignment: .topLeading
        )
    }

    private var toDosHeader: some View {
        ToDoMacTopLevelHeader(
            title: "toDō",
            eyebrow: nil,
            titleStyle: .brand,
            onBack: selectedToDo == nil ? leaveToDos : closeFocusedToDo
        ) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(macTransitionAnimation) {
                        isMacUtilityTrayVisible.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.todoMacSymbol(20, weight: .heavy))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: isMacUtilityTrayVisible ? ToDoMacPalette.brandBlue : ToDoMacPalette.raised,
                    foreground: isMacUtilityTrayVisible ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.ink
                ))
                .accessibilityLabel(isMacUtilityTrayVisible ? "Hide utilities" : "Show utilities")

                Button(action: openCreateEditor) {
                    Image(systemName: "plus")
                        .font(.todoMacSymbol(22, weight: .heavy))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.brandYellow,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Create new toDō")
                .accessibilityHint("Opens the new toDō editor.")
            }
        }
    }

    private var macUtilityTray: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.todoMacSymbol(14, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.brandBlue)
                TextField("Search toDōs, notes, tags, nanoDos", text: $macSearchText)
                    .textFieldStyle(.plain)
                    .font(.todoMacEntry(14))
                    .foregroundStyle(ToDoMacPalette.ink)
            }
            .padding(12)
            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 8) {
                ForEach(ToDoMacListFilter.allCases) { filter in
                    Button {
                        withAnimation(macTransitionAnimation) {
                            macListFilter = filter
                        }
                    } label: {
                        Label(filter.title, systemImage: filter.icon)
                            .lineLimit(1)
                    }
                    .buttonStyle(ToDoMacSelectablePillButtonStyle(color: filter.color, isSelected: macListFilter == filter))
                }
            }
        }
        .padding(14)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var macListEmptyState: some View {
        VStack(spacing: 8) {
            Text(hasActiveMacListFilters ? "No toDōs match this view." : "What’s worth doing today?")
                .font(.todoMacHeadline(20, relativeTo: .title3))
                .foregroundStyle(ToDoMacPalette.ink)
                .multilineTextAlignment(.center)

            Text(hasActiveMacListFilters ? "Shift the filters or begin a fresh one." : "Start with your first toDō.")
                .font(.todoMacUI(14, weight: .medium))
                .foregroundStyle(ToDoMacPalette.mutedInk)
                .multilineTextAlignment(.center)

            Button {
                openCreateEditor()
            } label: {
                Label("Add toDō", systemImage: "plus")
                    .frame(minWidth: 150)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(
                color: ToDoMacPalette.brandYellow,
                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
            ))
            .padding(.top, 6)
            .accessibilityHint("Opens the new toDō editor.")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var hasActiveMacListFilters: Bool {
        macListFilter != .all || !macSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var listSummaryFooter: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: visibleOverdueCount > 0 ? "exclamationmark" : "checkmark")
                .font(.todoMacSymbol(14, weight: .heavy))
                .foregroundStyle(visibleOverdueCount > 0 ? ToDoMacPalette.urgent : ToDoMacPalette.done)
                .frame(width: 26, height: 26)
                .background((visibleOverdueCount > 0 ? ToDoMacPalette.urgent : ToDoMacPalette.done).opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(listSummaryCountText)
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)

                Text(listSummarySentiment)
                    .font(.todoMacUI(11, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(ToDoMacPalette.raised.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ToDoMacPalette.mutedInk.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel("\(listSummaryCountText). \(listSummarySentiment)")
        .padding(.top, 34)
        .padding(.bottom, 18)
    }

    private var visibleOverdueCount: Int {
        filteredActiveToDos.filter { toDo in
            guard let dueDate = toDo.dueDate else { return false }
            return dueDate < .now
        }.count
    }

    private var listSummaryCountText: String {
        let visible = filteredActiveToDos.count
        let toDoText = AppLocalization.localizedCount(visible, singularKey: "%@ toDō", pluralKey: "%@ toDōs")
        let overdueText = AppLocalization.localizedCount(visibleOverdueCount, singularKey: "%@ overdue", pluralKey: "%@ overdue")
        return "\(toDoText) · \(overdueText)"
    }

    private var listSummarySentiment: String {
        let visible = filteredActiveToDos.count
        if visible == 0 {
            return String(localized: "Nothing is asking for attention in this view.")
        }

        if visibleOverdueCount > 0 {
            return String(localized: "Start with the overdue items, then reschedule anything that no longer belongs today.")
        }

        if visible <= 3 {
            return String(localized: "A short list. Pick the clearest next action and keep the surface clean.")
        }

        if visible >= 12 {
            return String(localized: "A heavy view. Narrow by tag, due date, or time-sensitive work before adding more.")
        }

        return String(localized: "A manageable set. Choose one toDō and move it forward.")
    }

    private func complete(_ toDo: ToDo) {
        if selectedToDoIdentity == toDo.selectionIdentity {
            closeFocusedToDo()
        }
        toDo.transition(to: .done)
        try? modelContext.save()
        refreshMacSurfaces()
        reloadMacData()
    }

    private func trash(_ toDo: ToDo) {
        guard canManageRemovalAction(for: toDo) else {
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Can’t remove shared toDō"),
                message: String(localized: "Only the toDō owner or shared-list owner can remove it."),
                style: .warning
            )
            return
        }
        if selectedToDoIdentity == toDo.selectionIdentity {
            closeFocusedToDo()
        }
        toDo.trashedAt = .now
        toDo.transition(to: .trashed)
        SyncDeletionMirroring.deleteDeviceOnlyCounterpartIfNeeded(
            for: toDo,
            in: modelContext,
            actingUserID: authStore.currentUserID,
            recordsSyncTombstone: false
        )
        do {
            try modelContext.save()
        } catch {
            AppLog.error("Failed to move Mac toDō to Trash: \(error)", logger: AppLog.app)
            modelContext.rollback()
            SyncCoordinator.shared.showTransientFeedback(
                title: String(localized: "Sync Failed"),
                message: String(localized: "Try Again"),
                style: .failure
            )
            reloadMacData()
            return
        }
        refreshMacSurfaces()
        reloadMacData()
    }

    private func canManageRemovalAction(for toDo: ToDo) -> Bool {
        guard SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere else {
            return true
        }

        guard let currentUserID = authStore.currentUserID else { return false }
        guard let collabID = toDo.collabID else {
            return toDo.ownerUserID == currentUserID
        }

        return toDo.ownerUserID == currentUserID
            || collaborationService.collabs.contains {
                $0.id == collabID && $0.ownerUserID == currentUserID
            }
    }

    private func refreshMacSurfaces() {
        NotificationManager.shared.scheduleRefresh()
        SyncCoordinator.shared.scheduleLocalSync()
    }
}

private enum ToDoMacListFilter: String, CaseIterable, Identifiable {
    case all
    case dueSoon
    case timeSensitive
    case overdue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .dueSoon:
            return String(localized: "Due Soon")
        case .timeSensitive:
            return String(localized: "Time-Sensitive")
        case .overdue:
            return String(localized: "Overdue")
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .dueSoon:
            return "clock.fill"
        case .timeSensitive:
            return "flame.fill"
        case .overdue:
            return "exclamationmark"
        }
    }

    var color: Color {
        switch self {
        case .all:
            return ToDoMacPalette.brandBlue
        case .dueSoon:
            return ToDoMacPalette.brandYellow
        case .timeSensitive, .overdue:
            return ToDoMacPalette.urgent
        }
    }
}

private enum ToDoMacHomeFilter: String, CaseIterable, Identifiable {
    case recent
    case dueSoon
    case timeSensitive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return String(localized: "Recent")
        case .dueSoon: return String(localized: "Due Soon")
        case .timeSensitive: return String(localized: "Time-Sensitive")
        }
    }

    var color: Color {
        switch self {
        case .recent: return ToDoMacPalette.brandBlue
        case .dueSoon: return ToDoMacPalette.brandYellow
        case .timeSensitive: return ToDoMacPalette.urgent
        }
    }
}

private enum ToDoMacEditorMode: Identifiable, Equatable {
    case create(UUID = UUID())
    case edit(ToDoSelectionIdentity)

    var id: String {
        switch self {
        case .create(let id):
            return "create-\(id.uuidString)"
        case .edit(let identity):
            return "edit-\(String(describing: identity))"
        }
    }

    var title: String {
        switch self {
        case .create:
            return String(localized: "New toDō")
        case .edit:
            return String(localized: "Edit toDō")
        }
    }

    var existingIdentity: ToDoSelectionIdentity? {
        if case .edit(let identity) = self { return identity }
        return nil
    }
}

private struct ToDoMacDetailPane: View {
    @Environment(\.colorScheme) private var colorScheme

    let toDo: ToDo
    let canRemove: Bool
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onTrash: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .accessibilityLabel("Close toDō")

                Text("Your toDō")
                    .font(.todoMacDisplay(34))
                    .foregroundStyle(ToDoMacPalette.brandYellow)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "arrow.up.right")
                        .font(.todoMacSymbol(22, weight: .heavy))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .accessibilityLabel("Edit toDō")
            }

            ScrollView {
                detailContent
                    .padding(.bottom, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(toDo.task)
                .font(.todoMacEntry(32, weight: .medium))
                .foregroundStyle(ToDoMacPalette.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 12) {
                ToDoMacAttributeCard(
                    title: toDo.dueDate == nil ? "Updated" : "Due",
                    value: AppLocalization.dateTimeString(toDo.dueDate ?? toDo.syncUpdatedAt),
                    icon: toDo.dueDate == nil ? "clock.arrow.circlepath" : "calendar.badge.clock",
                    color: ToDoMacPalette.brandYellow
                )
                ToDoMacAttributeCard(title: "Reminder", value: toDo.reminderIntent.title, icon: "bell.fill", color: reminderColor)
            }

            if let recurrenceSummary = toDo.recurrenceSummary {
                ToDoMacAttributeCard(
                    title: "Repeat",
                    value: recurrenceSummary,
                    icon: "arrow.triangle.2.circlepath",
                    color: ToDoMacPalette.brandBlue
                )
            }

            if !toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.todoMacDisplay(22))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                    Text(toDo.notes)
                        .font(.todoMacEntry(18))
                        .foregroundStyle(ToDoMacPalette.ink)
                }
                .padding(20)
                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            if !toDo.effectiveTags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tags")
                        .font(.todoMacDisplay(22))
                        .foregroundStyle(ToDoMacPalette.mutedInk)

                    ToDoMacFlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(toDo.effectiveTags) { tag in
                            Text(tag.displayName)
                                .font(.todoMacUI(13, weight: .bold))
                                .foregroundStyle(ToDoMacPalette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(ToDoMacPalette.raised, in: Capsule())
                        }
                    }
                }
            }

            if !toDo.nanoDos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NanoDos")
                        .font(.todoMacDisplay(22))
                        .foregroundStyle(ToDoMacPalette.mutedInk)

                    VStack(spacing: 8) {
                        ForEach(toDo.orderedNanoDos) { nanoDo in
                            HStack(spacing: 10) {
                                Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.todoMacSymbol(17, weight: .heavy))
                                    .foregroundStyle(nanoDo.isDone ? ToDoMacPalette.done : ToDoMacPalette.mutedInk)
                                Text(nanoDo.task)
                                    .font(.todoMacEntry(15))
                                    .foregroundStyle(ToDoMacPalette.ink)
                                    .strikethrough(nanoDo.isDone)
                                Spacer()
                                if let dueDate = nanoDo.dueDate {
                                    Text(AppLocalization.dateTimeString(dueDate))
                                        .font(.todoMacUI(11))
                                        .foregroundStyle(ToDoMacPalette.mutedInk)
                                }
                            }
                            .padding(12)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }

            if toDo.hasLocationReminder {
                locationCard
            }

            HStack(spacing: 14) {
                Button(action: onComplete) {
                    Label("Mark as done", systemImage: "checkmark")
                        .frame(minWidth: 104)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

                if canRemove {
                    Button(action: onTrash) {
                        Label("Trash", systemImage: "trash.fill")
                            .frame(minWidth: 104)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToDoMacAttributeCard(
                title: "Location",
                value: toDo.locationReminderLabel ?? toDo.locationReminderTrigger.title,
                icon: "location.fill",
                color: ToDoMacPalette.brandBlue
            )

            if let coordinate = locationCoordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                ))) {
                    Marker(toDo.locationReminderLabel ?? String(localized: "Location"), coordinate: coordinate)
                        .tint(ToDoMacPalette.brandBlue)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var locationCoordinate: CLLocationCoordinate2D? {
        guard let latitude = toDo.locationReminderLatitude,
              let longitude = toDo.locationReminderLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var reminderColor: Color {
        switch toDo.reminderIntent {
        case .soft: ToDoMacPalette.mutedInk
        case .due: ToDoMacPalette.brandYellow
        case .timeSensitive: ToDoMacPalette.urgent
        }
    }
}

private typealias ToDoMacNanoDoDraft = ToDoEditorNanoDoDraft

private struct ToDoMacEditorPane: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    @StateObject private var locationReminderService = LocationReminderService.shared

    let mode: ToDoMacEditorMode
    let existingToDo: ToDo?
    let availableTags: [Tag]
    let onCancel: () -> Void
    let onSave: (ToDo) -> Void

    @State private var task: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var reminderIntent: ToDoReminderIntent
    @State private var isRecurring: Bool
    @State private var recurrenceUnit: ToDoRecurrenceUnit
    @State private var recurrenceInterval: Int
    @State private var recurrenceMode: ToDoRecurrenceMode
    @State private var recurrenceCount: Int
    @State private var hasLocationReminder: Bool
    @State private var locationReminderLatitude: Double
    @State private var locationReminderLongitude: Double
    @State private var locationReminderRadius: Double
    @State private var locationReminderTrigger: ToDoLocationReminderTrigger
    @State private var locationReminderLabel: String
    @State private var isLocatingReminder = false
    @State private var completeWhenAllNanoDosDone: Bool
    @State private var selectedTagIDs: Set<PersistentIdentifier>
    @State private var selectedCollabID: UUID?
    @State private var newTagName: String
    @State private var nanoDrafts: [ToDoMacNanoDoDraft]
    @State private var isCreateTaskCommitted: Bool

    init(
        mode: ToDoMacEditorMode,
        existingToDo: ToDo?,
        availableTags: [Tag],
        onCancel: @escaping () -> Void,
        onSave: @escaping (ToDo) -> Void
    ) {
        self.mode = mode
        self.existingToDo = existingToDo
        self.availableTags = availableTags
        self.onCancel = onCancel
        self.onSave = onSave

        let existing = existingToDo
        _task = State(initialValue: existing?.task ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _hasDueDate = State(initialValue: existing?.dueDate != nil)
        _dueDate = State(initialValue: existing?.dueDate ?? .now.addingTimeInterval(60 * 60))
        _reminderIntent = State(initialValue: existing?.reminderIntent ?? .due)
        _isRecurring = State(initialValue: existing?.isRecurring ?? false)
        _recurrenceUnit = State(initialValue: existing?.recurrenceUnit ?? .days)
        _recurrenceInterval = State(initialValue: max(existing?.recurrenceInterval ?? 1, 1))
        _recurrenceMode = State(initialValue: existing?.recurrenceMode ?? .finite)
        _recurrenceCount = State(initialValue: max(existing?.recurrenceCount ?? 1, 1))
        _hasLocationReminder = State(initialValue: existing?.hasLocationReminder ?? false)
        _locationReminderLatitude = State(initialValue: existing?.locationReminderLatitude ?? 37.3349)
        _locationReminderLongitude = State(initialValue: existing?.locationReminderLongitude ?? -122.0090)
        _locationReminderRadius = State(initialValue: existing?.resolvedLocationReminderRadius ?? 150)
        _locationReminderTrigger = State(initialValue: existing?.locationReminderTrigger ?? .arriving)
        _locationReminderLabel = State(initialValue: existing?.locationReminderLabel ?? "")
        _completeWhenAllNanoDosDone = State(initialValue: existing?.completeWhenAllNanoDosDone ?? false)
        _selectedTagIDs = State(initialValue: Set(existing?.effectiveTags.map(\.id) ?? []))
        _selectedCollabID = State(initialValue: existing?.collabID)
        _newTagName = State(initialValue: "")
        _nanoDrafts = State(initialValue: existing?.orderedNanoDos.map { ToDoMacNanoDoDraft(nanoDo: $0) } ?? [])
        _isCreateTaskCommitted = State(initialValue: existing != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .accessibilityLabel("Cancel")

                Text(mode.title)
                    .font(.todoMacDisplay(34))
                    .tracking(0.8)
                    .foregroundStyle(ToDoMacPalette.brandYellow)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    editorSection("toDō") {
                        HStack(alignment: .top, spacing: 12) {
                            TextField("what toDō today?", text: $task, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...4)
                                .font(.todoMacEntry(22, weight: .medium))
                                .foregroundStyle(ToDoMacPalette.ink)
                                .padding(20)
                                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                            if existingToDo == nil && !isCreateTaskCommitted {
                                Button {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        isCreateTaskCommitted = true
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.todoMacSymbol(22, weight: .heavy))
                                        .frame(width: 48, height: 48)
                                }
                                .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(ToDoMacIconButtonStyle(
                                    color: ToDoMacPalette.brandYellow,
                                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                                ))
                                .accessibilityLabel("Continue creating toDō")
                            }
                        }
                    }

                    if isCreateTaskCommitted {
                    if canChooseCollabDestination, !collaborationService.collabs.isEmpty {
                        editorSection("Save To") {
                            HStack(spacing: 12) {
                                Image(systemName: selectedCollabID == nil ? "person.fill" : "person.2.fill")
                                    .font(.todoMacSymbol(15, weight: .bold))
                                    .foregroundStyle(ToDoMacPalette.brandBlue)

                                Picker("Save To", selection: $selectedCollabID) {
                                    Text("Personal").tag(Optional<UUID>.none)
                                    ForEach(collaborationService.collabs) { collab in
                                        Text(collab.name).tag(Optional(collab.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }

                    editorSection("Due + Reminder") {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $hasDueDate) {
                                Label("Due date", systemImage: "calendar.badge.clock")
                                    .font(.todoMacUI(16, weight: .bold))
                            }
                            .toggleStyle(.switch)

                            if hasDueDate {
                                HStack(spacing: 12) {
                                    Text("When")
                                        .font(.todoMacUI(14, weight: .bold))
                                        .foregroundStyle(ToDoMacPalette.mutedInk)

                                    DatePicker("When", selection: $dueDate)
                                    .labelsHidden()
                                    .font(.todoMacUI(15, weight: .semibold))
                                    .datePickerStyle(.compact)
                                }

                                HStack(spacing: 10) {
                                    ForEach(ToDoReminderIntent.allCases) { intent in
                                        Button {
                                            reminderIntent = intent
                                        } label: {
                                            Text(intent.title)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .buttonStyle(ToDoMacSelectablePillButtonStyle(
                                            color: reminderColor(for: intent),
                                            isSelected: reminderIntent == intent
                                        ))
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    editorSection("Repeat") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $isRecurring) {
                                Label("Recurring reminder", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.todoMacUI(16, weight: .bold))
                            }
                            .toggleStyle(.switch)
                            .disabled(!hasDueDate)

                            if !hasDueDate {
                                Text("Add a due date before repeating this toDō.")
                                    .font(.todoMacUI(12, weight: .semibold))
                                    .foregroundStyle(ToDoMacPalette.mutedInk)
                            }

                            if hasDueDate && isRecurring {
                                HStack(spacing: 10) {
                                    Stepper(value: $recurrenceInterval, in: 1...999) {
                                        Text(recurrenceUnit.displayLabel(for: recurrenceInterval))
                                            .font(.todoMacUI(14, weight: .bold))
                                            .foregroundStyle(ToDoMacPalette.ink)
                                    }

                                    Menu {
                                        ForEach(ToDoRecurrenceUnit.allCases) { unit in
                                            Button(unit.title) {
                                                recurrenceUnit = unit
                                            }
                                        }
                                    } label: {
                                        Label(recurrenceUnit.title, systemImage: "chevron.up.chevron.down")
                                            .font(.todoMacUI(13, weight: .bold))
                                    }
                                    .buttonStyle(ToDoMacSelectablePillButtonStyle(color: ToDoMacPalette.brandBlue, isSelected: true))
                                }

                                HStack(spacing: 10) {
                                    ForEach(ToDoRecurrenceMode.allCases) { mode in
                                        Button {
                                            recurrenceMode = mode
                                        } label: {
                                            Text(mode.title)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .buttonStyle(ToDoMacSelectablePillButtonStyle(
                                            color: ToDoMacPalette.brandBlue,
                                            isSelected: recurrenceMode == mode
                                        ))
                                    }
                                }

                                if recurrenceMode == .finite {
                                    Stepper(value: $recurrenceCount, in: 1...365) {
                                        HStack {
                                            Text("Additional reminders")
                                                .font(.todoMacUI(14, weight: .bold))
                                            Spacer()
                                            Text(AppLocalization.numberString(recurrenceCount))
                                                .font(.todoMacDisplay(20))
                                                .foregroundStyle(ToDoMacPalette.brandYellow)
                                        }
                                    }
                                }

                                Text(recurrenceSummaryText)
                                    .font(.todoMacUI(12, weight: .semibold))
                                    .foregroundStyle(ToDoMacPalette.mutedInk)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .padding(18)
                        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    editorSection("Tags") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                TextField("add tag", text: $newTagName)
                                    .textFieldStyle(.plain)
                                    .font(.todoMacEntry(16))
                                    .padding(13)
                                    .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .onSubmit(addTag)
                                Button(action: addTag) {
                                    Image(systemName: "plus")
                                        .font(.todoMacSymbol(15, weight: .heavy))
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                                .accessibilityLabel("Add tag")
                            }

                            ToDoMacFlowLayout(spacing: 8, rowSpacing: 8) {
                                ForEach(availableTags) { tag in
                                    Button {
                                        toggleTag(tag)
                                    } label: {
                                        Text(tag.displayName)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(ToDoMacSelectablePillButtonStyle(
                                        color: ToDoMacPalette.brandBlue,
                                        isSelected: selectedTagIDs.contains(tag.id)
                                    ))
                                }
                            }
                        }
                    }

                    editorSection("Location") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $hasLocationReminder) {
                                Label("Place reminder", systemImage: "location.fill")
                                    .font(.todoMacUI(16, weight: .bold))
                            }
                            .toggleStyle(.switch)

                            Text(locationReminderService.locationReminderStatusMessage)
                                .font(.todoMacUI(12, weight: .semibold))
                                .foregroundStyle(ToDoMacPalette.mutedInk)

                            if hasLocationReminder {
                                HStack(spacing: 10) {
                                    ForEach(ToDoLocationReminderTrigger.allCases) { trigger in
                                        Button {
                                            locationReminderTrigger = trigger
                                        } label: {
                                            Text(trigger.title)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .buttonStyle(ToDoMacSelectablePillButtonStyle(
                                            color: ToDoMacPalette.brandBlue,
                                            isSelected: locationReminderTrigger == trigger
                                        ))
                                    }
                                }

                                TextField("Place label", text: $locationReminderLabel)
                                    .textFieldStyle(.plain)
                                    .font(.todoMacEntry(16))
                                    .padding(13)
                                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                                HStack(spacing: 10) {
                                    TextField("Latitude", value: $locationReminderLatitude, format: .number.precision(.fractionLength(4...7)))
                                        .textFieldStyle(.plain)
                                        .font(.todoMacEntry(14))
                                        .padding(12)
                                        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    TextField("Longitude", value: $locationReminderLongitude, format: .number.precision(.fractionLength(4...7)))
                                        .textFieldStyle(.plain)
                                        .font(.todoMacEntry(14))
                                        .padding(12)
                                        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }

                                Stepper(value: locationReminderRadiusBinding, in: 100.0...1000.0, step: 50.0) {
                                    HStack {
                                        Text("Radius")
                                            .font(.todoMacUI(14, weight: .bold))
                                        Spacer()
                                        Text("\(AppLocalization.numberString(Int(locationReminderRadius))) m")
                                            .font(.todoMacUI(13, weight: .bold))
                                            .foregroundStyle(ToDoMacPalette.mutedInk)
                                    }
                                }

                                Button {
                                    Task { await setLocationReminderToCurrentLocation() }
                                } label: {
                                    Label(isLocatingReminder ? "Finding Location" : "Use Current Location", systemImage: "location.north.fill")
                                        .frame(minWidth: 174)
                                }
                                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                                .disabled(isLocatingReminder)
                            }
                        }
                        .padding(18)
                        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    editorSection("NanoDos") {
                        VStack(spacing: 10) {
                            Toggle(isOn: $completeWhenAllNanoDosDone) {
                                Text("Complete parent when all NanoDos are done")
                                    .font(.todoMacUI(15, weight: .bold))
                            }
                            .toggleStyle(.switch)
                            .padding(16)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                            ForEach($nanoDrafts) { $draft in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        Button {
                                            draft.isDone.toggle()
                                        } label: {
                                            Image(systemName: draft.isDone ? "checkmark.circle.fill" : "circle")
                                                .font(.todoMacSymbol(20, weight: .heavy))
                                                .frame(width: 34, height: 34)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(draft.isDone ? ToDoMacPalette.done : ToDoMacPalette.brandYellow)

                                        TextField("nanoDo", text: $draft.task)
                                            .textFieldStyle(.plain)
                                            .font(.todoMacEntry(16))

                                        Button {
                                            removeNanoDraft(draft)
                                        } label: {
                                            Image(systemName: "trash.fill")
                                                .font(.todoMacSymbol(14, weight: .heavy))
                                        .frame(width: 34, height: 34)
                                }
                                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                            }

                                    Toggle("Due for this NanoDo", isOn: $draft.hasDueDate)
                                        .font(.todoMacUI(13, weight: .bold))
                                        .toggleStyle(.switch)

                                    if draft.hasDueDate {
                                        DatePicker("When", selection: $draft.dueDate)
                                            .font(.todoMacUI(13, weight: .bold))
                                    }
                                }
                                .padding(16)
                                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }

                            Button {
                                nanoDrafts.append(ToDoMacNanoDoDraft())
                            } label: {
                                Label("Add NanoDo", systemImage: "plus")
                                    .frame(minWidth: 132)
                            }
                            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                        }
                    }

                    editorSection("Notes") {
                        TextField("notes", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...7)
                            .font(.todoMacEntry(16))
                            .foregroundStyle(ToDoMacPalette.ink)
                            .padding(18)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    }
                }
                .padding(.bottom, 8)
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isCreateTaskCommitted)
            }
            .scrollIndicators(.hidden)

            if isCreateTaskCommitted {
                Button(action: save) {
                    Label(existingToDo == nil ? "Create toDō" : "Save changes", systemImage: "checkmark")
                        .frame(minWidth: 150)
                }
                .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(26)
        .frame(minWidth: 560, maxWidth: 860, alignment: .topLeading)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func editorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.todoMacDisplay(24))
                .tracking(0.7)
                .foregroundStyle(ToDoMacPalette.mutedInk)
            content()
        }
    }

    private func reminderColor(for intent: ToDoReminderIntent) -> Color {
        switch intent {
        case .soft:
            return ToDoMacPalette.mutedInk
        case .due:
            return ToDoMacPalette.brandYellow
        case .timeSensitive:
            return ToDoMacPalette.urgent
        }
    }

    private func toggleTag(_ tag: Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else if selectedTagIDs.count < ToDo.maxTagSelection {
            selectedTagIDs.insert(tag.id)
        }
    }

    private func addTag() {
        let rawName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return }
        let normalized = Tag.normalizeName(rawName)
        let scopedTags = currentAvailableTags()
        if let existing = canonicalTag(named: normalized, in: scopedTags) {
            if selectedTagIDs.count < ToDo.maxTagSelection {
                selectedTagIDs.insert(existing.id)
            }
        } else {
            let ownerUserID = scopedOwnerUserID
            let tag = Tag(
                name: normalized,
                cloudID: ownerUserID == nil ? nil : UUID(),
                ownerUserID: ownerUserID
            )
            modelContext.insert(tag)
            if selectedTagIDs.count < ToDo.maxTagSelection {
                selectedTagIDs.insert(tag.id)
            }
        }
        newTagName = ""
    }

    private var scopedOwnerUserID: UUID? {
        ToDoMacAuthStore.shared.scopedOwnerUserID
    }

    private var canChooseCollabDestination: Bool {
        guard SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere else { return false }
        guard let existingToDo else { return true }
        return existingToDo.ownerUserID == scopedOwnerUserID
    }

    private func currentAvailableTags() -> [Tag] {
        let fetched = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? availableTags
        let ownerUserID = scopedOwnerUserID
        let visibleTagIDs = Set(availableTags.map(\.id))
        return Tag.canonicalTags(from: fetched.filter {
            $0.ownerUserID == ownerUserID || visibleTagIDs.contains($0.id)
        })
    }

    private func canonicalTag(named normalizedName: String, in tags: [Tag]) -> Tag? {
        tags
            .filter { Tag.normalizeName($0.name) == normalizedName }
            .sorted {
                if $0.cloudID != nil, $1.cloudID == nil { return true }
                if $0.cloudID == nil, $1.cloudID != nil { return false }
                return $0.createdAt < $1.createdAt
            }
            .first
    }

    private var recurrenceSummaryText: String {
        let cadence = "Every \(recurrenceUnit.displayLabel(for: recurrenceInterval))"
        switch recurrenceMode {
        case .continuous:
            return "\(cadence) continuously"
        case .finite:
            let label = recurrenceCount == 1
                ? String(localized: "1 additional time")
                : String(format: String(localized: "%@ additional times"), AppLocalization.numberString(recurrenceCount))
            return "\(cadence) for \(label)"
        }
    }

    private var locationReminderRadiusBinding: Binding<Double> {
        Binding(
            get: { locationReminderRadius },
            set: { locationReminderRadius = min(max($0, 100), 1_000) }
        )
    }

    private func removeNanoDraft(_ draft: ToDoMacNanoDoDraft) {
        nanoDrafts.removeAll { $0.id == draft.id }
    }

    private func setLocationReminderToCurrentLocation() async {
        guard !isLocatingReminder else { return }
        isLocatingReminder = true
        defer { isLocatingReminder = false }

        locationReminderService.requestLocationReminderAuthorization()
        guard let location = await locationReminderService.requestCurrentLocation() else {
            return
        }

        hasLocationReminder = true
        locationReminderLatitude = location.coordinate.latitude
        locationReminderLongitude = location.coordinate.longitude
        if locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            locationReminderLabel = String(localized: "Current Location")
        }
    }

    private func save() {
        var draft = ToDoEditorDraft(toDo: existingToDo)
        draft.task = task
        draft.notes = notes
        draft.hasDueDate = hasDueDate
        draft.dueDate = dueDate
        draft.reminderIntent = reminderIntent
        draft.completeWhenAllNanoDosDone = completeWhenAllNanoDosDone
        draft.collabID = selectedCollabID
        draft.selectedTagIDs = selectedTagIDs
        draft.nanoDos = nanoDrafts

        guard let savedToDo = try? draft.save(
            existingToDo: existingToDo,
            availableTags: currentAvailableTags(),
            ownerUserID: scopedOwnerUserID,
            context: modelContext
        ) else {
            return
        }

        if hasDueDate && isRecurring {
            savedToDo.recurrenceUnit = recurrenceUnit
            savedToDo.recurrenceInterval = recurrenceInterval
            savedToDo.recurrenceMode = recurrenceMode
            savedToDo.recurrenceCount = recurrenceMode == .finite ? recurrenceCount : nil
            savedToDo.recurrenceAnchorDate = dueDate
            savedToDo.recurrenceEndDate = nil
            savedToDo.markUpdated()
            try? modelContext.save()
        } else if savedToDo.isRecurring {
            savedToDo.clearRecurrence()
            try? modelContext.save()
        }

        if hasLocationReminder {
            locationReminderService.requestLocationReminderAuthorization()
            savedToDo.locationReminderLatitude = locationReminderLatitude
            savedToDo.locationReminderLongitude = locationReminderLongitude
            savedToDo.locationReminderRadius = locationReminderRadius
            savedToDo.locationReminderTrigger = locationReminderTrigger
            savedToDo.locationReminderLabel = locationReminderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            savedToDo.markUpdated()
            try? modelContext.save()
            locationReminderService.syncMonitoring(for: savedToDo)
        } else if savedToDo.hasLocationReminder {
            savedToDo.clearLocationReminder()
            try? modelContext.save()
            locationReminderService.syncMonitoring(for: savedToDo)
        }

        onSave(savedToDo)
    }
}

private struct ToDoMacSelectablePillButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    let color: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.todoMacUI(13, weight: .bold))
            .foregroundStyle(isSelected ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isSelected ? color : ToDoMacPalette.raised, in: Capsule())
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

private struct ToDoMacFilterButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    let color: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.todoMacUI(12, weight: .bold))
            .foregroundStyle(isSelected ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? color : ToDoMacPalette.raised, in: Capsule())
            .overlay {
                if !isSelected {
                    Capsule().stroke(color.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct ToDoMacHomeReadOnlyRow: View {
    let toDo: ToDo

    var body: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(
                systemName: toDo.reminderIntent == .timeSensitive ? "flame.fill" : "clock.fill",
                color: reminderColor,
                size: 13,
                dimension: 30
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(toDo.task)
                    .font(.todoMacEntry(16, weight: .medium))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                Text(toDo.dueDate.map(AppLocalization.dateTimeString) ?? toDo.reminderIntent.title)
                    .font(.todoMacUI(12))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            Spacer()
        }
        .padding(14)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reminderColor: Color {
        toDo.reminderIntent == .timeSensitive ? ToDoMacPalette.urgent : ToDoMacPalette.brandYellow
    }
}

private struct ToDoMacSettingsPane: View {
    let toDos: [ToDo]
    let onSkipAuthentication: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @AppStorage(ToDoMacPreferenceKeys.doneSwipePrimaryAction) private var removalActionRaw = ToDoMacRemovalAction.archive.rawValue
    @AppStorage(ToDoMacPreferenceKeys.appAppearanceMode) private var appearanceModeRaw = ToDoMacAppearanceMode.system.rawValue
    @AppStorage(ToDoMacPreferenceKeys.showDockIcon) private var showDockIcon = true
    @AppStorage(ToDoMacPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(ToDoMacPreferenceKeys.appliedDockIconAtLaunch) private var appliedDockIconAtLaunch = true
    @AppStorage(ToDoMacPreferenceKeys.appliedMenuBarExtraAtLaunch) private var appliedMenuBarExtraAtLaunch = true
    @State private var pendingIconChange: ToDoMacIconChange?
    @State private var isShowingGuidedTour = false
    @State private var isShowingAbout = false
    @State private var isShowingProfile = false
    @State private var selectedPreferenceDestination: ToDoMacPreferenceDestination?
    @State private var pendingPreferenceDestination: ToDoMacPreferenceDestination?
    @State private var selectedCollabForDetail: ToDoCollab?
    @State private var selectedDataDestination: ToDoMacDataDestination?
    @State private var pendingDataDestination: ToDoMacDataDestination?
    @State private var selectedModalDataDestination: ToDoMacDataDestination?

    private let brandWebsiteURL = URL(string: "https://yourtodo.today")!
    private let shiftWebsiteURL = URL(string: "https://iamshift.dev")!

    private var archiveCount: Int { toDos.filter { $0.lifecycleState == .archived || $0.lifecycleState == .done }.count }
    private var trashCount: Int { toDos.filter { $0.lifecycleState == .trashed }.count }

    private var hasSelectedDetail: Bool {
        selectedCollabForDetail != nil
            || selectedPreferenceDestination != nil
            || selectedDataDestination == .dataControls
    }

    private var removalAction: ToDoMacRemovalAction {
        ToDoMacRemovalAction(rawValue: removalActionRaw) ?? .archive
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .center, spacing: 22) {
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        settingsContent
                            .padding(.bottom, 10)
                    }
                    .scrollIndicators(.hidden)
                    // Use the section stack's ideal height until the menu is
                    // genuinely taller than the window. This prevents a short
                    // Settings menu from painting an empty full-height card.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: min(max(proxy.size.width * 0.36, 320), 440), alignment: .top)
                    .frame(maxHeight: proxy.size.height * 0.86, alignment: .top)

                if let selectedCollabForDetail {
                    ToDoMacSettingsDetailPanel(
                        title: "Collabs",
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                self.selectedCollabForDetail = nil
                            }
                        }
                    ) {
                        ToDoMacCollabUsersSheet(
                            collab: selectedCollabForDetail,
                            onClose: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                    self.selectedCollabForDetail = nil
                                }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                } else if let selectedPreferenceDestination {
                    ToDoMacSettingsDetailPanel(
                        title: selectedPreferenceDestination.title,
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                self.selectedPreferenceDestination = nil
                            }
                        }
                    ) {
                        preferenceContent(for: selectedPreferenceDestination)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                } else if selectedDataDestination == .dataControls {
                    ToDoMacSettingsDetailPanel(
                        title: ToDoMacDataDestination.dataControls.title,
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                self.selectedDataDestination = nil
                            }
                        }
                    ) {
                        ToDoMacDataOverviewSheet(
                            destination: .dataControls,
                            toDos: toDos,
                            onClose: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                                    self.selectedDataDestination = nil
                                }
                            },
                            showsHeader: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .topLeading
                )

                madeByBrandView
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: selectedPreferenceDestination)
        .alert(item: $pendingIconChange) { change in
            Alert(
                title: Text(change.title),
                message: Text("This change requires quitting and reopening toDō before the Mac can apply it cleanly."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .default(Text("Proceed")) {
                    applyIconChange(change)
                }
            )
        }
        .sheet(isPresented: $isShowingGuidedTour) {
            ToDoMacGuidedTourSheet()
        }
        .sheet(isPresented: $isShowingAbout) {
            ToDoMacAboutSheet()
        }
        .sheet(isPresented: $isShowingProfile, onDismiss: {
            Task { await authStore.refreshProfile() }
        }) {
            ToDoMacProfileSheet()
        .frame(
            minWidth: 620,
            idealWidth: 720,
            maxWidth: nil,
            minHeight: 620,
            idealHeight: 760,
            maxHeight: nil
        )
        }
        .sheet(item: $selectedModalDataDestination) { destination in
            ToDoMacDataOverviewSheet(destination: destination, toDos: toDos)
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            accountAndSyncSection
            preferencesSection
            dataManagementSection
            aboutSection
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var settingsPrimaryColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            accountAndSyncSection
            preferencesSection
        }
    }

    private var settingsSecondaryColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            dataManagementSection
            aboutSection
        }
    }

    private var accountAndSyncSection: some View {
        ToDoMacSettingsSection(title: "Account & Sync") {
            ToDoMacAccountStatusCard(
                onOpenProfile: { isShowingProfile = true },
                onSkipAuthentication: onSkipAuthentication
            )
            ToDoMacCollabsCard { collab in
                openCollabDetail(collab)
            }
            ToDoMacSettingsDestination(
                title: "Membership",
                value: purchaseManager.membershipLabel,
                systemName: "globe",
                color: ToDoMacPalette.brandBlue
            ) { openPreference(.membership) }
            ToDoMacSettingsDestination(
                title: "Sync",
                value: syncCoordinator.effectiveSyncMode.title,
                systemName: "arrow.triangle.2.circlepath",
                color: syncStatusColor
            ) { openPreference(.sync) }
        }
    }

    private var preferencesSection: some View {
        ToDoMacSettingsSection(title: "Preferences") {
            ToDoMacSettingsDestination(
                title: "Appearance",
                value: appearanceTitle(for: ToDoMacAppearanceMode(rawValue: appearanceModeRaw) ?? .system),
                systemName: appearanceIcon(for: ToDoMacAppearanceMode(rawValue: appearanceModeRaw) ?? .system),
                color: ToDoMacPalette.brandYellow
            ) { openPreference(.appearance) }
            ToDoMacSettingsDestination(
                title: "Behavior",
                value: removalAction.compactTitle,
                systemName: removalAction.systemImage,
                color: removalAction == .delete ? ToDoMacPalette.urgent : ToDoMacPalette.brandYellow
            ) { openPreference(.behavior) }
            ToDoMacSettingsDestination(
                title: "Notifications",
                value: String(localized: "Reminder Alerts"),
                systemName: "bell.badge.fill",
                color: ToDoMacPalette.brandBlue
            ) { openPreference(.notifications) }
            ToDoMacSettingsDestination(
                title: "Guided Tour",
                value: String(localized: "Open"),
                systemName: "sparkles",
                color: ToDoMacPalette.brandYellow
            ) { openGuidedTour() }
        }
    }

    private var dataManagementSection: some View {
        ToDoMacSettingsSection(title: "Manage Your Data") {
            ToDoMacSettingsDestination(
                title: "Data Controls",
                value: String(localized: "Preferences"),
                systemName: "slider.horizontal.3",
                color: ToDoMacPalette.brandBlue
            ) { openDataDestination(.dataControls) }
            ToDoMacSettingsDestination(
                title: "Archives",
                value: AppLocalization.numberString(archiveCount),
                systemName: "archivebox.fill",
                color: ToDoMacPalette.brandYellow
            ) { openDataDestination(.archives) }
            ToDoMacSettingsDestination(
                title: "Trash",
                value: AppLocalization.numberString(trashCount),
                systemName: "trash.fill",
                color: ToDoMacPalette.urgent
            ) { openDataDestination(.trash) }
        }
    }

    private var aboutSection: some View {
        ToDoMacSettingsSection(title: "About") {
            ToDoMacSettingsDestination(
                title: "About toDō",
                value: appVersionLabel,
                systemName: "info.circle.fill",
                color: ToDoMacPalette.brandBlue
            ) { openAbout() }
        }
    }

    @ViewBuilder
    private func preferenceContent(for destination: ToDoMacPreferenceDestination) -> some View {
        switch destination {
        case .sync:
            ToDoMacSyncStatusCard()
            ToDoMacSyncModeControl()
        case .appearance:
            HStack(spacing: 12) {
                ForEach(appearanceOptions, id: \.rawValue) { option in
                    ToDoMacAppearanceChoiceButton(
                        title: appearanceTitle(for: option),
                        systemName: appearanceIcon(for: option),
                        color: appearanceColor(for: option),
                        isSelected: appearanceModeRaw == option.rawValue
                    ) {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            appearanceModeRaw = option.rawValue
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            ToDoMacRestartToggleRow(
                title: "Dock Icon",
                detail: "Keep toDō visible in the Dock.",
                systemName: "dock.rectangle",
                isOn: showDockIcon,
                needsRestart: showDockIcon != appliedDockIconAtLaunch
            ) {
                pendingIconChange = .dock(!showDockIcon)
            }

            ToDoMacRestartToggleRow(
                title: "Menu Bar Icon",
                detail: "Keep quick access beside the system status icons.",
                systemName: "menubar.rectangle",
                isOn: showMenuBarExtra,
                needsRestart: showMenuBarExtra != appliedMenuBarExtraAtLaunch
            ) {
                pendingIconChange = .menuBar(!showMenuBarExtra)
            }
        case .behavior:
            ForEach(ToDoMacRemovalAction.allCases) { action in
                ToDoMacChoiceButton(
                    title: action.compactTitle,
                    subtitle: removalSubtitle(for: action),
                    systemName: action.systemImage,
                    color: action == .delete ? ToDoMacPalette.urgent : ToDoMacPalette.brandYellow,
                    isSelected: removalActionRaw == action.rawValue
                ) {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        removalActionRaw = action.rawValue
                    }
                }
            }
        case .notifications:
            ToDoMacNotificationStatusCard()
        case .membership:
            ToDoMacCommerceSection()
        }
    }

    private var syncStatusColor: Color {
        switch syncCoordinator.syncActivityState {
        case .failed:
            return ToDoMacPalette.urgent
        case .activating, .syncing:
            return ToDoMacPalette.brandBlue
        case .synced:
            return ToDoMacPalette.done
        case .idle:
            return ToDoMacPalette.mutedInk
        }
    }

    private func openPreference(_ destination: ToDoMacPreferenceDestination) {
        guard selectedPreferenceDestination != destination else { return }

        if selectedCollabForDetail != nil || selectedDataDestination != nil {
            pendingPreferenceDestination = destination
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedCollabForDetail = nil
                selectedDataDestination = nil
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard pendingPreferenceDestination == destination else { return }
                pendingPreferenceDestination = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedPreferenceDestination = destination
                }
            }
        } else if selectedPreferenceDestination != nil {
            pendingPreferenceDestination = destination
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedPreferenceDestination = nil
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard pendingPreferenceDestination == destination else { return }
                pendingPreferenceDestination = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedPreferenceDestination = destination
                }
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                selectedPreferenceDestination = destination
            }
        }
    }

    private func openDataDestination(_ destination: ToDoMacDataDestination) {
        if destination == .dataControls {
        if selectedPreferenceDestination != nil || selectedCollabForDetail != nil || selectedDataDestination != nil {
            pendingDataDestination = destination
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedPreferenceDestination = nil
                selectedCollabForDetail = nil
                selectedDataDestination = nil
            }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(280))
                    guard pendingDataDestination == destination else { return }
                    pendingDataDestination = nil
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        selectedDataDestination = destination
                    }
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedDataDestination = destination
                }
            }
            return
        }

        if selectedPreferenceDestination != nil || selectedCollabForDetail != nil || selectedDataDestination != nil {
            pendingDataDestination = destination
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedPreferenceDestination = nil
                selectedCollabForDetail = nil
                selectedDataDestination = nil
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard pendingDataDestination == destination else { return }
                pendingDataDestination = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedModalDataDestination = destination
                }
            }
        } else {
            selectedModalDataDestination = destination
        }
    }

    private func openCollabDetail(_ collab: ToDoCollab) {
        if selectedPreferenceDestination != nil || selectedDataDestination != nil {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedPreferenceDestination = nil
                selectedDataDestination = nil
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    selectedCollabForDetail = collab
                }
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                selectedCollabForDetail = collab
            }
        }
    }

    private func openGuidedTour() {
        guard selectedCollabForDetail != nil || selectedPreferenceDestination != nil || selectedDataDestination != nil else {
            isShowingGuidedTour = true
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            selectedCollabForDetail = nil
            selectedPreferenceDestination = nil
            selectedDataDestination = nil
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            isShowingGuidedTour = true
        }
    }

    private func openAbout() {
        guard selectedCollabForDetail != nil || selectedPreferenceDestination != nil || selectedDataDestination != nil else {
            isShowingAbout = true
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            selectedCollabForDetail = nil
            selectedPreferenceDestination = nil
            selectedDataDestination = nil
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            isShowingAbout = true
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return String(format: String(localized: "Version %@"), version)
    }

    private var madeByBrandView: some View {
        VStack(spacing: 12) {
            Text("\(Text("toDō").font(.todoMacBrand(18)).foregroundStyle(ToDoMacPalette.brandYellow).bold()) \(Text(String(localized: "what matters")))")
                .font(.todoMacUI(16, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
                .multilineTextAlignment(.center)

            Link(destination: brandWebsiteURL) {
                Text(verbatim: "yourtodo.today")
                    .font(.todoMacUI(13, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.brandBlue)
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                Text(verbatim: "by")
                    .font(.todoMacUI(12))
                    .foregroundStyle(ToDoMacPalette.mutedInk)

                Link(destination: shiftWebsiteURL) {
                    HStack(spacing: 10) {
                        Image("brand-logomark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .aspectRatio(1, contentMode: .fit)

                        HStack(spacing: 0) {
                            Text(verbatim: "mo").font(.todoMacUI(18, weight: .bold))
                            Text(verbatim: "i").italic().font(.todoMacUI(18, weight: .bold))
                            Text(verbatim: "n.").font(.todoMacUI(18, weight: .bold))
                            Text(verbatim: "sh").italic().font(.todoMacUI(18, weight: .bold))
                            Text(verbatim: "i").font(.todoMacUI(18, weight: .bold))
                            Text(verbatim: "ft()").italic().font(.todoMacUI(18, weight: .bold))
                        }
                        .foregroundStyle(ToDoMacPalette.ink)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 30)
        .padding(.bottom, 8)
    }

    private var appearanceOptions: [ToDoMacAppearanceMode] {
        [.system, .light, .dark]
    }

    private func applyIconChange(_ change: ToDoMacIconChange) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            switch change {
            case .dock(let isOn):
                showDockIcon = isOn
                if !isOn, !showMenuBarExtra {
                    showMenuBarExtra = true
                }
            case .menuBar(let isOn):
                showMenuBarExtra = isOn
                if !isOn, !showDockIcon {
                    showDockIcon = true
                }
            }
        }
    }

    private func removalSubtitle(for action: ToDoMacRemovalAction) -> String {
        switch action {
        case .archive:
            return String(localized: "Keep it retrievable.")
        case .delete:
            return String(localized: "Move it to trash.")
        }
    }

    private func appearanceTitle(for option: ToDoMacAppearanceMode) -> String {
        switch option {
        case .system:
            return String(localized: "System")
        case .light:
            return String(localized: "Light")
        case .dark:
            return String(localized: "Dark")
        }
    }

    private func appearanceSubtitle(for option: ToDoMacAppearanceMode) -> String {
        switch option {
        case .system:
            return String(localized: "Follow macOS.")
        case .light:
            return String(localized: "Keep it bright.")
        case .dark:
            return String(localized: "Keep it dark.")
        }
    }

    private func appearanceIcon(for option: ToDoMacAppearanceMode) -> String {
        switch option {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    private func appearanceColor(for option: ToDoMacAppearanceMode) -> Color {
        switch option {
        case .system:
            return ToDoMacPalette.brandBlue
        case .light:
            return ToDoMacPalette.brandYellow
        case .dark:
            return ToDoMacPalette.ink
        }
    }
}

private enum ToDoMacRemovalAction: String, CaseIterable, Identifiable {
    case archive
    case delete

    var id: String { rawValue }

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
}

private enum ToDoMacIconChange: Identifiable {
    case dock(Bool)
    case menuBar(Bool)

    var id: String {
        switch self {
        case .dock(let isOn):
            return "dock-\(isOn)"
        case .menuBar(let isOn):
            return "menu-bar-\(isOn)"
        }
    }

    var title: String {
        switch self {
        case .dock(let isOn):
            return isOn ? String(localized: "Show Dock Icon?") : String(localized: "Hide Dock Icon?")
        case .menuBar(let isOn):
            return isOn ? String(localized: "Show Menu Bar Icon?") : String(localized: "Hide Menu Bar Icon?")
        }
    }
}

private enum ToDoMacPreferenceDestination: String, Identifiable {
    case sync
    case appearance
    case behavior
    case notifications
    case membership

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sync: return String(localized: "Sync")
        case .appearance: return String(localized: "Appearance")
        case .behavior: return String(localized: "Behavior")
        case .notifications: return String(localized: "Notifications")
        case .membership: return String(localized: "toDō+")
        }
    }
}

private enum ToDoMacDataDestination: String, Identifiable {
    case dataControls
    case archives
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dataControls: return String(localized: "Data Controls")
        case .archives: return String(localized: "Archives")
        case .trash: return String(localized: "Trash")
        }
    }
}

private struct ToDoMacSettingsDestination: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    let systemName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ToDoMacIconBadge(systemName: systemName, color: color, size: 14, dimension: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.todoMacBodyStrong(16, relativeTo: .headline))
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text(value)
                        .font(.todoMacBody(12, relativeTo: .subheadline))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.todoMacSymbol(12, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(color, in: Circle())
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ToDoMacSettingsDetailPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            panelBody(scrolls: false)
            panelBody(scrolls: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private func panelBody(scrolls: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(15, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close")

                Text(title)
                    .font(.todoMacViewTitle(28))
                    .foregroundStyle(ToDoMacPalette.ink)

                Spacer()
            }

            Divider()

            if scrolls {
                ScrollView {
                    panelContent
                }
                .scrollIndicators(.hidden)
            } else {
                panelContent
            }
        }
    }

    private var panelContent: some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.bottom, 4)
    }
}

private struct ToDoMacCommerceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .black))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close")

                Text("toDō+")
                    .font(.todoMacViewTitle(34))
                    .foregroundStyle(ToDoMacPalette.ink)

                Spacer(minLength: 0)
            }

            ScrollView {
                ToDoMacCommerceSection()
                    .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .frame(
            minWidth: 720,
            idealWidth: 780,
            maxWidth: nil,
            minHeight: 640,
            idealHeight: 720,
            maxHeight: nil
        )
        .background(ToDoMacPalette.background)
    }
}

private struct ToDoMacAboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingReleaseHistory = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .heavy))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close")

                Text("About toDō")
                    .font(.todoMacViewTitle(30))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 24)

            ScrollView {
                aboutContent
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .frame(
            minWidth: 680,
            idealWidth: 740,
            maxWidth: nil,
            minHeight: 520,
            idealHeight: 680,
            maxHeight: nil
        )
        .background(ToDoMacPalette.background)
        .sheet(isPresented: $isShowingReleaseHistory) {
            ToDoMacReleaseHistorySheet(currentVersion: versionLabel)
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("toDō is a productivity system built for the user to help you stay organized without getting in your way. From everyday tasks and shopping lists to bigger plans and everything beyond, it’s designed to work the way you do.")
                    .font(.todoMacLongForm(17))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Take a little time to explore. Try different ways of organizing your tasks, make the app your own, and see what works best for you. Visit yourtodo.today to learn more about toDō, and follow my Substack for release notes, engineering talk, and the thinking behind each update.")
                    .font(.todoMacLongForm(17))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(Text("Hi, I’m moin.").fontWeight(.heavy)) I built toDō because I wanted a productivity app that felt simple, thoughtful, and enjoyable to use every day. It’s been a long journey, and I’m still making it better with every release. If you’d like to learn more about my work, you’ll find me at iamshift.dev.")
                    .font(.todoMacLongForm(17))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Text("shift beneath the view")
                .font(.todoMacUI(17, weight: .heavy))
                .foregroundStyle(ToDoMacPalette.ink)
                .tracking(1.0)
                .padding(.top, 14)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)

            macAboutSectionHeading("Release Notes")
            releasePreview

            macAboutSectionHeading("Made with Intention")
            HStack(spacing: 16) {
                macBrandLink(
                    title: "moin.shift()",
                    destination: URL(string: "https://iamshift.dev")!
                )
                macBrandLink(
                    title: "toDō today",
                    logoName: "todo-today-logo",
                    destination: URL(string: "https://yourtodo.today")!
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)

            macSupportLink
                .frame(maxWidth: 330)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            macAboutSectionHeading("Legal")
            HStack(spacing: 6) {
                compactExternalLink(title: "Privacy Policy", destination: URL(string: "https://yourtodo.today/legal/privacy.html")!)
                compactExternalLink(title: "Terms of Use", destination: URL(string: "https://yourtodo.today/legal/terms.html")!)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: 680, alignment: .topLeading)
    }

    private var releasePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.todoMacSymbol(15, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.brandBlue)
                    .frame(width: 15, height: 15)

                Text("Version")
                    .font(.todoMacUI(14, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)

                Text(verbatim: versionLabel)
                    .font(.todoMacCode(14, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            ForEach(Array(currentReleaseNotes.enumerated()), id: \.offset) { index, note in
                releasePreviewRow(note, isHighlight: index < 2)
            }

            Button {
                isShowingReleaseHistory = true
            } label: {
                HStack(spacing: 7) {
                    Text("All Release History")
                        .font(.todoMacUI(13, weight: .bold))
                    Image(systemName: "arrow.up.right")
                        .font(.todoMacSymbol(12, weight: .heavy))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(ToDoMacPalette.brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows release notes for every version")
            .padding(.top, 6)
        }
    }

    private var currentReleaseNotes: [LocalizedStringKey] {
        [
            "Added toDō+ membership, Pioneer recognition, account profiles, and expanded personal Collabs.",
            "Improved account-safe sync, migration, conflict handling, and deletion recovery.",
            "Improved voice entry, NanoDos, reminders, onboarding, and accessibility.",
            "Expanded standalone Apple Watch sync and native Mac support.",
            "And much more, shaped around the way you work."
        ]
    }

    private func releasePreviewRow(_ text: LocalizedStringKey, isHighlight: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(ToDoMacPalette.brandYellow)
                .frame(width: 6, height: 6)
                .frame(width: 15, alignment: .center)

            Text(text)
                .font(.todoMacCode(13, weight: isHighlight ? .bold : .regular))
                .foregroundStyle(ToDoMacPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func macAboutSectionHeading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.todoMacDisplay(24))
            .tracking(0.65)
            .foregroundStyle(ToDoMacPalette.brandBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.top, 24)
            .padding(.bottom, 6)
    }

    private func macBrandLink(
        title: LocalizedStringKey,
        logoName: String = "brand-logomark",
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.todoMacSymbol(16, weight: .heavy))
                        .foregroundStyle(ToDoMacPalette.brandBlue)
                }

                Image(logoName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)

                Text(title)
                    .font(.todoMacUI(18, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(width: 118, height: 118)
        }
        .buttonStyle(.plain)
    }

    private var macSupportLink: some View {
        Link(destination: URL(string: "mailto:support@iamshift.dev")!) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.todoMacSymbol(14, weight: .bold))
                Text(verbatim: "support@iamshift.dev")
                    .font(.todoMacUI(16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
            .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
            .padding(14)
            .frame(maxWidth: 420, minHeight: 52, alignment: .center)
            .background(ToDoMacPalette.brandBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func compactExternalLink(
        title: LocalizedStringKey,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: 1) {
                Text(title)
                    .font(.todoMacUI(14, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.todoMacSymbol(11, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.brandBlue)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(minHeight: 52, alignment: .leading)
            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var versionLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

private struct ToDoMacReleaseHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let currentVersion: String

    private let previousReleases: [(version: String, notes: [LocalizedStringKey])] = [
        ("3.0.1", [
            "Improved sync reliability across devices.",
            "Refined notifications, widgets, Live Activities, and localization.",
            "Fixed stability and presentation issues reported after 3.0."
        ]),
        ("3.0", [
            "Introduced Home, Momentum, and the redesigned toDō workflow.",
            "Added toDō Sync, Apple Watch, Mac, widgets, and Live Activities.",
            "Rebuilt the app around a consistent cross-platform design."
        ])
    ]

    private var currentNotes: [LocalizedStringKey] {
        [
            "Added toDō+ membership, Pioneer recognition, account profiles, and expanded personal Collabs.",
            "Improved account-safe sync, migration, conflict handling, and deletion recovery.",
            "Improved voice entry, NanoDos, reminders, onboarding, and accessibility.",
            "Expanded standalone Apple Watch sync and native Mac support.",
            "And much more, shaped around the way you work."
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .heavy))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close")

                VStack(alignment: .leading, spacing: 3) {
                    Text("Release History")
                        .font(.todoMacViewTitle(34))
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text("See what changed, release by release.")
                        .font(.todoMacUI(13, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }
                Spacer(minLength: 0)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    releaseCard(version: currentVersion, notes: currentNotes, isCurrent: true)
                    ForEach(Array(previousReleases.enumerated()), id: \.offset) { _, release in
                        releaseCard(version: release.version, notes: release.notes, isCurrent: false)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(24)
        .frame(
            minWidth: 620,
            idealWidth: 680,
            maxWidth: nil,
            minHeight: 520,
            idealHeight: 620,
            maxHeight: nil
        )
        .background(ToDoMacPalette.background)
    }

    private func releaseCard(
        version: String,
        notes: [LocalizedStringKey],
        isCurrent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(verbatim: version)
                    .font(.todoMacDisplay(25))
                    .tracking(0.65)
                    .foregroundStyle(ToDoMacPalette.ink)
                if isCurrent {
                    Text("Latest")
                        .font(.todoMacUI(11, weight: .heavy))
                        .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(ToDoMacPalette.brandBlue, in: Capsule())
                }
            }

            ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(ToDoMacPalette.brandYellow)
                        .frame(width: 6, height: 6)
                    Text(note)
                        .font(.todoMacCode(14, weight: isCurrent && index < 2 ? .bold : .regular))
                        .foregroundStyle(ToDoMacPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct ToDoMacCommerceSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor
    @State private var isRedeemingOfferCode = false
    @State private var selectedProductForDetails: ToDoProductCatalog.ProductID?
    @State private var isMembershipIconGlowing = false

    private let plusProducts: [ToDoProductCatalog.ProductID] = [
        .plusMonthly,
        .plusYearly,
        .plusLifetime,
    ]
    private let supportProducts: [ToDoProductCatalog.ProductID] = [
        .appreciationCoffee,
        .appreciationLunch,
        .appreciationPatron,
        .appreciationFounding,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if purchaseManager.displayedIsPioneer || purchaseManager.displayedIsFoundingSupporter {
                macRecognitionBanner
            } else {
                macMembershipIdentityBlock
            }

            if purchaseManager.accountID == nil {
                Label("Sign in to connect your membership and recognition to your toDō account.", systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
            }

            if purchaseManager.displayedHasPlus || purchaseManager.displayedIsPioneer || purchaseManager.displayedIsFoundingSupporter {
                VStack(alignment: .leading, spacing: 7) {
                    if purchaseManager.displayedHasPlus || purchaseManager.displayedIsPioneer {
                        macBenefitRow("Send unlimited personal Collab invitations", systemName: "paperplane.fill")
                        macBenefitRow("Receive new toDō+ features as they are released", systemName: "sparkles")
                    }
                    if purchaseManager.displayedIsPioneer {
                        macBenefitRow("Every feature, free and paid, now and ahead, is included.", systemName: "infinity")
                    } else if purchaseManager.displayedIsFoundingSupporter {
                        macBenefitRow("Founding recognition included", systemName: "heart.fill")
                    }
                }
            }

            if purchaseManager.displayedShouldShowPlusPurchaseOptions {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(plusProducts, id: \.rawValue) { productID in
                        productButton(productID, presentsDetails: true)
                    }
                }

                Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Your Apple Account is charged at confirmation and manages renewal.")
                    .font(.todoMacUI(11, weight: .medium))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Keep toDō moving")
                    .font(.todoMacDisplay(20))
                    .tracking(0.65)
                    .foregroundStyle(ToDoMacPalette.ink)

                Spacer(minLength: 12)

                Button {
                    Task { await purchaseManager.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .font(.todoMacUI(12, weight: .bold))
                }
                .buttonStyle(ToDoMacSecondaryButtonStyle())
                .disabled(purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
            }

            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(visibleSupportProducts, id: \.rawValue) { productID in
                    productButton(productID)
                }
            }

            VStack(spacing: 12) {
                Button {
                    isRedeemingOfferCode = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "ticket.fill")
                        Text("Redeem Offer Code")
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.up.right")
                            .font(.todoMacSymbol(11, weight: .heavy))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ToDoMacSecondaryButtonStyle())
                .disabled(!connectivityMonitor.isAvailable)

                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack(spacing: 8) {
                        Text("Manage Subscriptions")
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.up.right")
                            .font(.todoMacSymbol(11, weight: .heavy))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacSecondaryButtonStyle())
                .disabled(!connectivityMonitor.isAvailable)
            }

            if let statusMessage = purchaseManager.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.done)
            }
            if let errorMessage = purchaseManager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
            }
        }
        .modifier(ToDoOfferCodeRedemptionModifier(isPresented: $isRedeemingOfferCode) {
            Task { await purchaseManager.refreshAfterOfferCodeRedemption() }
        })
        .sheet(item: $selectedProductForDetails) { productID in
            ToDoMacSubscriptionDetailsSheet(productID: productID)
                .environmentObject(purchaseManager)
        }
    }

    private func macBenefitRow(_ title: LocalizedStringKey, systemName: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemName)
                .font(.todoMacSymbol(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.brandBlue)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.todoMacUI(12, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macMembershipIdentityBlock: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(
                systemName: purchaseManager.displayedHasPlus ? "checkmark.seal.fill" : "person.crop.circle",
                color: purchaseManager.displayedHasPlus ? ToDoMacPalette.done : ToDoMacPalette.brandBlue,
                size: 15,
                dimension: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(purchaseManager.displayedHasPlus ? "toDō+" : String(localized: "toDō"))
                    .font(.todoMacDisplay(22))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)

                Text(purchaseManager.displayedMembershipLabel)
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            Spacer()

            if purchaseManager.isLoading || purchaseManager.isLoadingAccountEntitlements {
                ProgressView()
            }
        }
    }

    private var macRecognitionBanner: some View {
        let isPioneer = purchaseManager.displayedIsPioneer
        let isFoundingSupporter = purchaseManager.displayedIsFoundingSupporter
        let foreground = Color.white

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isPioneer ? "sparkles" : "heart.fill")
                    .font(.todoMacSymbol(22, weight: .black))
                    .foregroundStyle(isPioneer ? Color.white : ToDoMacPalette.brandBlue)
                    .frame(width: 28, height: 28)
                    .shadow(
                        color: isPioneer ? ToDoMacPalette.brandBlue.opacity(isMembershipIconGlowing ? 1.0 : 0.62) : .clear,
                        radius: isPioneer ? (isMembershipIconGlowing ? 12 : 6) : 0
                    )
                    .onAppear {
                        guard isPioneer, !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            isMembershipIconGlowing = true
                        }
                    }
                    .onChange(of: reduceMotion) { _, isReduced in
                        if isReduced {
                            isMembershipIconGlowing = false
                        } else if isPioneer {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                                isMembershipIconGlowing = true
                            }
                        }
                    }
                Text(isPioneer ? "toDō Pioneer" : "Founding Supporter")
                    .font(.todoMacDisplay(29))
                    .tracking(0.6)
                    .foregroundStyle(Color.white)

                Spacer(minLength: 0)
            }

            Text(isPioneer
                 ? "Every feature, free and paid, now and ahead, is included."
                 : "A lasting thank-you for backing toDō early.")
                .font(.todoMacUI(14, weight: .bold))
                .foregroundStyle(foreground)
                .fixedSize(horizontal: false, vertical: true)

            if isPioneer, isFoundingSupporter {
                Text("Founding Supporter")
                    .font(.todoMacDisplay(18))
                    .tracking(0.25)
                    .foregroundStyle(foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            ToDoBrandRecognitionBackground()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ToDoMacPalette.brandBlue.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var productColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 12, alignment: .top)]
    }

    private var visibleSupportProducts: [ToDoProductCatalog.ProductID] {
        supportProducts.filter { productID in
            if productID == .appreciationFounding && !purchaseManager.displayedShouldShowFoundingSupporterPurchase {
                return false
            }

            return productID != .appreciationFounding
                || purchaseManager.products[productID.rawValue] != nil
                || !purchaseManager.missingProductIDs.contains(productID.rawValue)
        }
    }

    private func productButton(
        _ productID: ToDoProductCatalog.ProductID,
        presentsDetails: Bool = false
    ) -> some View {
        let product = purchaseManager.products[productID.rawValue]
        let isOwned = purchaseManager.activeProductIDs.contains(productID.rawValue)
        let isPurchasing = purchaseManager.activePurchaseProductID == productID.rawValue

        return Button {
            Task {
                if product == nil {
                    await purchaseManager.loadProducts()
                }
                guard purchaseManager.products[productID.rawValue] != nil else { return }
                if presentsDetails {
                    selectedProductForDetails = productID
                } else {
                    await purchaseManager.purchase(productID: productID.rawValue)
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(productTitle(productID))
                        .font(.todoMacDisplay(19))
                        .tracking(0.6)
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text(productDetail(productID))
                        .font(.todoMacUI(11, weight: .medium))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Spacer(minLength: 6)

                if isPurchasing {
                    ProgressView()
                } else if isOwned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ToDoMacPalette.done)
                } else {
                    Text(product?.displayPrice ?? String(localized: "Retry"))
                        .font(.todoMacUI(14, weight: .heavy))
                        .foregroundStyle(ToDoMacPalette.brandBlue)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isOwned || purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
    }

    private func productTitle(_ productID: ToDoProductCatalog.ProductID) -> String {
        switch productID {
        case .plusMonthly: return String(localized: "Monthly")
        case .plusYearly: return String(localized: "Annual")
        case .plusLifetime: return String(localized: "Lifetime")
        case .appreciationCoffee: return String(localized: "Coffee for toDō")
        case .appreciationLunch: return String(localized: "Lunch for toDō")
        case .appreciationPatron: return String(localized: "Patron of Dōing")
        case .appreciationFounding: return String(localized: "Founding Supporter")
        }
    }

    private func productDetail(_ productID: ToDoProductCatalog.ProductID) -> String {
        switch productID {
        case .plusMonthly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusMonthly)
                ? String(localized: "First week free for new subscribers. Renews monthly.")
                : String(localized: "Renews monthly.")
        case .plusYearly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusYearly)
                ? String(localized: "First two weeks free for new subscribers. Renews annually.")
                : String(localized: "Renews annually.")
        case .plusLifetime: return String(localized: "One payment. Permanent access to toDō+.")
        case .appreciationCoffee:
            return String(localized: "Thanks. Here's a coffee.")
        case .appreciationLunch:
            return String(localized: "I've been getting real value from toDō.")
        case .appreciationPatron:
            return String(localized: "I believe in where this project is going.")
        case .appreciationFounding:
            return String(localized: "Permanent recognition")
        }
    }
}

private struct ToDoMacSubscriptionDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var purchaseManager: ToDoPurchaseManager
    @EnvironmentObject private var connectivityMonitor: ToDoConnectivityMonitor

    let productID: ToDoProductCatalog.ProductID

    private var product: Product? {
        purchaseManager.products[productID.rawValue]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product?.displayName ?? productID.rawValue)
                        .font(.todoMacDisplay(28))
                        .tracking(0.7)
                        .foregroundStyle(ToDoMacPalette.ink)

                    if let product {
                        Text(product.displayPrice)
                            .font(.todoMacUI(20, weight: .heavy))
                            .foregroundStyle(ToDoMacPalette.brandBlue)
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .heavy))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(
                    color: ToDoMacPalette.urgent,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .accessibilityLabel("Close")
            }

            Text(macSubscriptionDetail(for: productID))
                .font(.todoMacUI(14, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                macSubscriptionBenefit("Send unlimited personal Collab invitations", systemName: "paperplane.fill")
                macSubscriptionBenefit("Receive new toDō+ features as they are released", systemName: "sparkles")
                macSubscriptionBenefit("Share eligible purchases with your Apple family", systemName: "figure.2.and.child.holdinghands")
            }

            Spacer(minLength: 0)

            Button {
                Task {
                    await purchaseManager.purchase(productID: productID.rawValue)
                    dismiss()
                }
            } label: {
                Text("Continue")
                    .font(.todoMacUI(15, weight: .heavy))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(
                color: ToDoMacPalette.brandYellow,
                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
            ))
            .disabled(product == nil || purchaseManager.isLoading || purchaseManager.activePurchaseProductID != nil || !connectivityMonitor.isAvailable)
        }
        .padding(24)
        .frame(minWidth: 430, minHeight: 390)
        .background(ToDoMacPalette.background)
    }

    private func macSubscriptionDetail(for productID: ToDoProductCatalog.ProductID) -> String {
        switch productID {
        case .plusMonthly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusMonthly)
                ? String(localized: "First week free for new subscribers. Renews monthly.")
                : String(localized: "Renews monthly.")
        case .plusYearly:
            return purchaseManager.isEligibleForIntroductoryOffer(.plusYearly)
                ? String(localized: "First two weeks free for new subscribers. Renews annually.")
                : String(localized: "Renews annually.")
        case .plusLifetime:
            return String(localized: "One payment. Permanent access to toDō+.")
        default:
            return ""
        }
    }

    private func macSubscriptionBenefit(_ title: LocalizedStringKey, systemName: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemName)
                .font(.todoMacSymbol(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.brandBlue)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(.todoMacUI(13, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToDoMacDataOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @EnvironmentObject private var collaborationService: ToDoCollaborationService
    @AppStorage("trashAutoEmptyInterval") private var trashAutoEmptyIntervalRaw = ToDoMacTrashAutoEmptyInterval.oneMonth.rawValue
    @AppStorage(ToDoMacPreferenceKeys.doneSwipePrimaryAction) private var removalActionRaw = ToDoMacRemovalAction.archive.rawValue
    @State private var isShowingDataResetConfirmation = false
    @State private var isShowingSharedListResetChoice = false
    @State private var isResettingToDoData = false
    @State private var dataResetResultMessage = ""
    @State private var isShowingDataResetResult = false

    let destination: ToDoMacDataDestination
    let toDos: [ToDo]
    let onClose: (() -> Void)?
    let showsHeader: Bool

    init(
        destination: ToDoMacDataDestination,
        toDos: [ToDo],
        onClose: (() -> Void)? = nil,
        showsHeader: Bool = true
    ) {
        self.destination = destination
        self.toDos = toDos
        self.onClose = onClose
        self.showsHeader = showsHeader
    }

    private var destinationToDos: [ToDo] {
        switch destination {
        case .dataControls:
            return []
        case .archives:
            return toDos
                .filter { $0.lifecycleState == .archived || $0.lifecycleState == .done }
                .sorted { $0.syncUpdatedAt > $1.syncUpdatedAt }
        case .trash:
            return toDos
                .filter { $0.lifecycleState == .trashed }
                .sorted { ($0.trashedAt ?? $0.syncUpdatedAt) > ($1.trashedAt ?? $1.syncUpdatedAt) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showsHeader {
                HStack(spacing: 16) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.todoMacSymbol(13, weight: .heavy))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                    .accessibilityLabel("Close")

                    Text(destination.title)
                        .font(.todoMacViewTitle(30))
                        .foregroundStyle(ToDoMacPalette.ink)

                    Spacer(minLength: 0)
                }
            }

            if destination == .dataControls {
                dataControls
            } else if destinationToDos.isEmpty {
                Text(destination == .archives ? "No completed or archived toDōs" : "Trash is empty.")
                    .font(.todoMacUI(15, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(destinationToDos) { toDo in
                            HStack(spacing: 12) {
                                ToDoMacIconBadge(
                                    systemName: destination == .archives ? "archivebox.fill" : "trash.fill",
                                    color: destination == .archives ? ToDoMacPalette.brandYellow : ToDoMacPalette.urgent,
                                    size: 13,
                                    dimension: 34
                                )
                                Text(toDo.task)
                                    .font(.todoMacEntry(15, weight: .medium))
                                    .foregroundStyle(ToDoMacPalette.ink)
                                    .lineLimit(2)
                                Spacer()
                                Text(AppLocalization.dateString(toDo.syncUpdatedAt))
                                    .font(.todoMacUI(11, weight: .bold))
                                    .foregroundStyle(ToDoMacPalette.mutedInk)
                            }
                            .padding(13)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(24)
        .frame(
            minWidth: showsHeader ? 520 : 0,
            idealWidth: showsHeader ? 620 : nil,
            maxWidth: nil,
            minHeight: showsHeader ? 360 : 0,
            idealHeight: showsHeader ? 560 : nil,
            maxHeight: nil,
            alignment: .top
        )
        .background(ToDoMacPalette.background)
        .confirmationDialog(
            "Reset all personal toDō data?",
            isPresented: $isShowingDataResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) {
                if hasJoinedSharedLists {
                    isShowingSharedListResetChoice = true
                } else {
                    resetToDoData(sharedListChoice: .keep)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every personal toDō and NanoDo on this device and synced account. Your account, tags, preferences, purchases, and shared lists stay intact.")
        }
        .confirmationDialog(
            "What should happen to shared lists?",
            isPresented: $isShowingSharedListResetChoice,
            titleVisibility: .visible
        ) {
            Button("Keep Shared Lists") {
                resetToDoData(sharedListChoice: .keep)
            }
            Button("Leave Shared Lists", role: .destructive) {
                resetToDoData(sharedListChoice: .leave)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keeping preserves the lists and your permissions. Leaving removes your access to lists shared with you. Shared lists you own remain in place.")
        }
        .alert("toDō Data Reset", isPresented: $isShowingDataResetResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataResetResultMessage)
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private var dataControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            ToDoMacSectionHeader(title: "Trash")

            Menu {
                ForEach(ToDoMacTrashAutoEmptyInterval.allCases) { interval in
                    Button(interval.title) {
                        trashAutoEmptyIntervalRaw = interval.rawValue
                    }
                }
            } label: {
                ToDoMacSettingsRow(
                    title: "Auto-Empty Trash",
                    value: (ToDoMacTrashAutoEmptyInterval(rawValue: trashAutoEmptyIntervalRaw) ?? .oneMonth).title,
                    systemName: "trash.slash.fill"
                )
            }
            .menuStyle(.borderlessButton)

            Button {
                removalActionRaw = ToDoMacRemovalAction.archive.rawValue
                trashAutoEmptyIntervalRaw = ToDoMacTrashAutoEmptyInterval.oneMonth.rawValue
            } label: {
                Label("Reset Choices", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Start Fresh")
                    .font(.todoMacDisplay(20))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.urgent)
                    .textCase(.uppercase)

                Text("Permanently deletes personal toDōs and NanoDos without deleting your account, tags, or purchases.")
                    .font(.todoMacUI(12))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                isShowingDataResetConfirmation = true
            } label: {
                Label(
                    isResettingToDoData ? "Resetting toDō Data" : "Reset toDō Data",
                    systemImage: isResettingToDoData ? "hourglass" : "trash.slash.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            .disabled(isResettingToDoData)
        }
        .padding(18)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hasJoinedSharedLists: Bool {
        guard let userID = authStore.currentUserID else { return false }
        return collaborationService.collabs.contains { $0.ownerUserID != userID }
    }

    private func resetToDoData(sharedListChoice: ToDoDataResetSharedListChoice) {
        guard !isResettingToDoData else { return }
        isResettingToDoData = true

        Task { @MainActor in
            do {
                let report = try await ToDoDataResetService.reset(
                    toDos: toDos,
                    accountUserID: authStore.currentUserID,
                    sharedListChoice: sharedListChoice,
                    collaborationService: collaborationService,
                    in: modelContext
                )
                NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
                dataResetResultMessage = dataResetMessage(for: report)
            } catch {
                dataResetResultMessage = String(
                    format: String(localized: "Your toDō data could not be reset: %@"),
                    error.localizedDescription
                )
            }
            isResettingToDoData = false
            isShowingDataResetResult = true
        }
    }

    private func dataResetMessage(for report: ToDoDataResetReport) -> String {
        var parts = [
            String(
                format: String(localized: "%@ personal toDōs were permanently deleted."),
                AppLocalization.numberString(report.deletedPersonalToDoCount)
            )
        ]
        if report.leftSharedListCount > 0 {
            parts.append(String(
                format: String(localized: "You left %@ shared lists."),
                AppLocalization.numberString(report.leftSharedListCount)
            ))
        }
        if report.preservedOwnedSharedListCount > 0 {
            parts.append(String(
                format: String(localized: "%@ shared lists you own were preserved."),
                AppLocalization.numberString(report.preservedOwnedSharedListCount)
            ))
        }
        return parts.joined(separator: " ")
    }
}

private enum ToDoMacTrashAutoEmptyInterval: String, CaseIterable, Identifiable {
    case oneWeek = "1 Week"
    case twoWeeks = "2 Weeks"
    case oneMonth = "1 Month"
    case threeMonths = "3 Months"
    case never = "Never"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

private struct ToDoMacGuidedTourSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let steps: [ToDoMacGuidedTourStep] = [
        .init(
            title: String(localized: "Start at Home"),
            detail: String(localized: "Create a toDō, open the full list, or read your current momentum from one place."),
            systemName: "house.fill",
            color: ToDoMacPalette.brandYellow
        ),
        .init(
            title: String(localized: "Shape the toDō"),
            detail: String(localized: "Add due dates, reminders, tags, notes, NanoDos, repeat rules, and location reminders from the editor."),
            systemName: "slider.horizontal.3",
            color: ToDoMacPalette.brandBlue
        ),
        .init(
            title: String(localized: "Work the List"),
            detail: String(localized: "Use Utilities to search and filter, then open a toDō beside the list when you need the focused view."),
            systemName: "list.bullet.rectangle.fill",
            color: ToDoMacPalette.done
        ),
        .init(
            title: String(localized: "Set the Defaults"),
            detail: String(localized: "Settings controls sync, notification behavior, appearance, and whether removing a toDō archives or trashes it."),
            systemName: "gearshape.fill",
            color: ToDoMacPalette.urgent
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                ToDoMacIconBadge(systemName: "sparkles", color: ToDoMacPalette.brandYellow, size: 22, dimension: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Guided Tour")
                        .font(.todoMacDisplay(38))
                        .tracking(0.9)
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text("A quick map of how toDō works on Mac.")
                        .font(.todoMacUI(15, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.todoMacSymbol(13, weight: .heavy))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .accessibilityLabel("Close Guided Tour")
            }

            VStack(spacing: 12) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        ToDoMacIconBadge(systemName: step.systemName, color: step.color, size: 16, dimension: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.todoMacDisplay(23))
                                .tracking(0.7)
                                .foregroundStyle(ToDoMacPalette.ink)
                            Text(step.detail)
                                .font(.todoMacUI(13, weight: .bold))
                                .foregroundStyle(ToDoMacPalette.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Enter toDō")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        }
        .padding(28)
        .frame(width: 560)
        .background(ToDoMacPalette.background)
    }
}

private struct ToDoMacGuidedTourStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemName: String
    let color: Color
}

private struct ToDoMacRestartToggleRow: View {
    let title: String
    let detail: String
    let systemName: String
    let isOn: Bool
    let needsRestart: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(
                systemName: systemName,
                color: isOn ? ToDoMacPalette.brandYellow : ToDoMacPalette.raised,
                size: 14,
                dimension: 34
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.todoMacUI(15, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.ink)

                    if needsRestart {
                        ToDoMacRestartTag()
                    }
                }
                Text(detail)
                    .font(.todoMacUI(12, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .lineLimit(1)
            }

            Spacer()

            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { _ in action() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ToDoMacRestartTag: View {
    var body: some View {
        Text("Restart")
            .font(.todoMacDisplay(12))
            .tracking(0.45)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(ToDoMacPalette.urgent.opacity(0.18), in: Capsule())
            .foregroundStyle(ToDoMacPalette.urgent)
    }
}

private struct ToDoMacIconStatusRow: View {
    let title: String
    let detail: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(
                systemName: systemName,
                color: ToDoMacPalette.brandYellow,
                size: 14,
                dimension: 34
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.todoMacUI(15, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)
                Text(detail)
                    .font(.todoMacUI(12, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ToDoMacAccountStatusCard: View {
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onOpenProfile: () -> Void
    let onSkipAuthentication: () -> Void
    @State private var authenticationIntent: ToDoAccountAuthenticationIntent = .signIn
    @State private var expectedUsername = ""
    @State private var submittedUsername: String?
    @State private var isContinuingWithoutAccount = false
    @FocusState private var isUsernameFocused: Bool

    private var normalizedUsername: String? {
        try? ToDoProfilePolicy.validatedUsername(expectedUsername)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
            ToDoMacIconBadge(
                systemName: authStore.isAuthenticated ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus",
                color: authStore.isAuthenticated ? ToDoMacPalette.done : ToDoMacPalette.brandYellow,
                size: 18,
                dimension: 42
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(authStore.isAuthenticated ? authStore.accountDisplayName : String(localized: "Sign in to toDō"))
                    .font(.todoMacUI(18, weight: .heavy))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)

                Text(accountDetail)
                    .font(.todoMacUI(13, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

                if authStore.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let error = authStore.lastErrorMessage, !error.isEmpty {
                Text(macAuthDisplayError(error))
                    .font(.todoMacUI(12, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.urgent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                if authStore.hasResolvedAccount {
                    Button {
                        onOpenProfile()
                    } label: {
                        Label("My Profile", systemImage: "person.text.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign-in Methods")
                            .font(.todoMacUI(15, weight: .heavy))
                            .foregroundStyle(ToDoMacPalette.mutedInk)

                        providerLinkRow(
                            title: "Apple",
                            systemName: "apple.logo",
                            isConnected: authStore.isProviderLinked("apple")
                        ) {
                            Task { _ = await authStore.linkAppleIdentity() }
                        }
                        providerLinkRow(
                            title: "Google",
                            systemName: "globe",
                            isConnected: authStore.isProviderLinked("google")
                        ) {
                            Task { _ = await authStore.linkGoogleIdentity() }
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        Task { await authStore.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                    .disabled(authStore.isAuthenticating)

                } else if authStore.isAuthenticated {
                    ToDoMacAccountSetupView()

                } else {
                    Picker("Account action", selection: $authenticationIntent) {
                        Text("Sign In").tag(ToDoAccountAuthenticationIntent.signIn)
                        Text("Create Account").tag(ToDoAccountAuthenticationIntent.createAccount)
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        TextField("Username", text: $expectedUsername)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .focused($isUsernameFocused)
                            .onSubmit(showProviderChoices)

                        Button(action: showProviderChoices) {
                            Image(systemName: "arrow.right")
                                .font(.todoMacUI(17, weight: .heavy))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(
                            ToDoMacIconButtonStyle(
                                color: ToDoMacPalette.brandYellow,
                                foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                            )
                        )
                        .disabled(normalizedUsername == nil || authStore.isAuthenticating)
                        .opacity(normalizedUsername == nil ? 0.42 : 1)
                        .accessibilityLabel("Continue")
                    }

                    if let submittedUsername {
                        VStack(spacing: 10) {
                            Button {
                                Task {
                                    await authStore.signInWithApple(
                                        intent: authenticationIntent,
                                        expectedUsername: submittedUsername
                                    )
                                }
                            } label: {
                                Label("Sign In with Apple", systemImage: "apple.logo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                            .disabled(authStore.isAuthenticating)

                            Button {
                                Task {
                                    await authStore.signInWithGoogle(
                                        intent: authenticationIntent,
                                        expectedUsername: submittedUsername
                                    )
                                }
                            } label: {
                                Label("Google", systemImage: "globe")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                            .disabled(authStore.isAuthenticating)
                        }
                        .transition(providerChoicesTransition)
                    }

                    Button(action: skipAuthentication) {
                        HStack(spacing: 12) {
                            if isContinuingWithoutAccount {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "externaldrive")
                                    .font(.todoMacSymbol(16, weight: .bold))
                                    .foregroundStyle(ToDoMacPalette.brandBlue)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("You can stay on this device.")
                                    .font(.todoMacUI(14, weight: .heavy))
                                    .foregroundStyle(ToDoMacPalette.ink)

                                Text("Local toDōs stay on this device. Account toDōs stay private until you sign in again.")
                                    .font(.todoMacUI(12, weight: .semibold))
                                    .foregroundStyle(ToDoMacPalette.mutedInk)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.todoMacSymbol(20, weight: .bold))
                                .foregroundStyle(ToDoMacPalette.brandBlue)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            ToDoMacPalette.panel,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isContinuingWithoutAccount || authStore.isAuthenticating)
                }
            }
        }
        .padding(16)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: authStore.resolvedAccountID) {
            await authStore.refreshLinkedProviders()
        }
        .onChange(of: expectedUsername) { _, _ in
            collapseProviderChoicesWhenUsernameChanges()
        }
        .onChange(of: authenticationIntent) { _, _ in
            collapseProviderChoices()
        }
    }

    private var providerChoicesTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .trailing).combined(with: .opacity)
    }

    private func showProviderChoices() {
        guard let normalizedUsername else {
            isUsernameFocused = true
            return
        }

        isUsernameFocused = false
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            submittedUsername = normalizedUsername
        }
    }

    private func collapseProviderChoicesWhenUsernameChanges() {
        guard let submittedUsername,
              submittedUsername != normalizedUsername else { return }
        collapseProviderChoices()
    }

    private func collapseProviderChoices() {
        guard submittedUsername != nil else { return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            submittedUsername = nil
        }
    }

    private func skipAuthentication() {
        guard !isContinuingWithoutAccount else { return }
        isContinuingWithoutAccount = true
        Task { @MainActor in
            let didContinue = await authStore.continueWithoutSigningIn()
            isContinuingWithoutAccount = false
            guard didContinue else { return }
            expectedUsername = ""
            submittedUsername = nil
            onSkipAuthentication()
        }
    }

    private func providerLinkRow(
        title: String,
        systemName: String,
        isConnected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .frame(width: 20)
                .foregroundStyle(ToDoMacPalette.brandBlue)

            Text(title)
                .font(.todoMacUI(13, weight: .semibold))
                .foregroundStyle(ToDoMacPalette.ink)

            Spacer(minLength: 8)

            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.todoMacUI(12, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.done)
            } else {
                Button("Connect", action: action)
                    .buttonStyle(ToDoMacSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountDetail: String {
        if authStore.hasResolvedAccount {
            if let provider = authStore.providerLabel {
                return String(format: String(localized: "Connected through %@."), provider)
            }
            return String(localized: "Connected and ready for toDō Sync.")
        }
        if authStore.isAuthenticated {
            return String(localized: "Finish account setup before using toDō Sync.")
        }
        return String(localized: "Use Apple or Google to keep toDō Sync available on this Mac.")
    }

    private func macAuthDisplayError(_ message: String) -> String {
        if message.localizedCaseInsensitiveContains("Unsupported provider: missing OAuth secret") {
            return String(localized: "Apple sign-in needs one more server setting. Google is available right now.")
        }
        return message
    }
}

private struct ToDoMacAccountSetupView: View {
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @State private var username = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(description)
                .font(.todoMacUI(12, weight: .semibold))
                .foregroundStyle(ToDoMacPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if case .accountMismatch(let expected, let actual) = authStore.accountResolution {
                Text("You entered @\(expected), but this provider account is @\(actual).")
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.urgent)
                Button("Continue as @\(actual)") {
                    Task { _ = await authStore.continueWithAuthenticatedAccount() }
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: .white))
            } else {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                Button("Continue") {
                    Task { _ = await authStore.completeAccountSetup(username: username) }
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: .white))
                .disabled((try? ToDoProfilePolicy.validatedUsername(username)) == nil)
            }
        }
        .onAppear {
            if case .migrationRequired(let existingUsername) = authStore.accountResolution {
                username = existingUsername ?? ""
            }
        }
    }

    private var description: String {
        switch authStore.accountResolution {
        case .migrationRequired:
            return String(localized: "Confirm your existing username to finish moving this account. Your toDōs and purchases stay with it.")
        case .accountMismatch:
            return String(localized: "The provider account does not match the username entered. Nothing was linked or moved.")
        default:
            return String(localized: "Choose a username for this account. Apple or Google remains the proof of ownership.")
        }
    }
}

private struct ToDoMacSyncModeControl: View {
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @State private var selectedMode: SyncMode = SyncCoordinator.shared.preferredSyncMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ToDoMacIconBadge(systemName: syncIcon, color: syncColor, size: 14, dimension: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Where to Save")
                        .font(.todoMacUI(15, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text(syncDetail)
                        .font(.todoMacUI(12, weight: .semibold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Spacer()

                Text(syncCoordinator.effectiveSyncMode.title)
                    .font(.todoMacUI(13, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
            }

            VStack(spacing: 12) {
                ForEach(SyncMode.allCases) { mode in
                    ToDoMacChoiceButton(
                        title: modePickerTitle(for: mode),
                        subtitle: syncModeSubtitle(for: mode),
                        systemName: syncModeIcon(for: mode),
                        color: syncModeColor(for: mode),
                        isSelected: selectedMode == mode
                    ) {
                        selectedMode = mode
                    }
                }
            }
            .onAppear {
                selectedMode = syncCoordinator.preferredSyncMode
            }
            .onChange(of: syncCoordinator.preferredSyncMode) { _, newValue in
                selectedMode = newValue
            }
            .onChange(of: selectedMode) { _, newValue in
                guard newValue != syncCoordinator.preferredSyncMode else { return }
                Task {
                    await syncCoordinator.setPreferredSyncMode(
                        newValue,
                        userID: authStore.resolvedAccountID,
                        shouldTransferData: true
                    )
                    selectedMode = syncCoordinator.preferredSyncMode
                }
            }

            if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.hasResolvedAccount {
                Text("Sign in to activate toDō Sync on this Mac.")
                    .font(.todoMacUI(12, weight: .semibold))
                    .foregroundStyle(ToDoMacPalette.brandYellow)
            }
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var syncDetail: String {
        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return String(format: String(localized: "%@ selected. Currently using %@."), syncCoordinator.preferredSyncMode.title, syncCoordinator.effectiveSyncMode.title)
        }
        return syncCoordinator.effectiveSyncMode.subtitle
    }

    private var syncIcon: String {
        switch syncCoordinator.effectiveSyncMode {
        case .deviceOnly:
            return "internaldrive.fill"
        case .iCloud:
            return "icloud.fill"
        case .syncEverywhere:
            return "cloud.fill"
        }
    }

    private var syncColor: Color {
        switch syncCoordinator.effectiveSyncMode {
        case .deviceOnly:
            return ToDoMacPalette.brandYellow
        case .iCloud:
            return ToDoMacPalette.brandBlue
        case .syncEverywhere:
            return authStore.isAuthenticated ? ToDoMacPalette.done : ToDoMacPalette.brandYellow
        }
    }

    private func modePickerTitle(for mode: SyncMode) -> String {
        switch mode {
        case .deviceOnly:
            return String(localized: "This Mac")
        case .iCloud:
            return String(localized: "iCloud")
        case .syncEverywhere:
            return String(localized: "toDō Sync")
        }
    }

    private func syncModeSubtitle(for mode: SyncMode) -> String {
        switch mode {
        case .deviceOnly:
            return String(localized: "Keep it here.")
        case .iCloud:
            return String(localized: "Apple devices.")
        case .syncEverywhere:
            return String(localized: "All platforms.")
        }
    }

    private func syncModeIcon(for mode: SyncMode) -> String {
        switch mode {
        case .deviceOnly:
            return "internaldrive.fill"
        case .iCloud:
            return "icloud.fill"
        case .syncEverywhere:
            return "cloud.fill"
        }
    }

    private func syncModeColor(for mode: SyncMode) -> Color {
        switch mode {
        case .deviceOnly:
            return ToDoMacPalette.brandYellow
        case .iCloud:
            return ToDoMacPalette.brandBlue
        case .syncEverywhere:
            return ToDoMacPalette.done
        }
    }
}

private struct ToDoMacSyncStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ToDoMacIconBadge(
                    systemName: statusIcon,
                    color: statusColor,
                    size: 14,
                    dimension: 34
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(statusTitle)
                            .font(.todoMacUI(15, weight: .bold))
                            .foregroundStyle(statusColor)

                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .tint(statusColor)
                        }
                    }

                    Text(statusDetail)
                        .font(.todoMacUI(12, weight: .semibold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if canRefresh {
                Button {
                    refreshSync()
                } label: {
                    Label("Refresh toDō Sync", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(
                    color: ToDoMacPalette.brandBlue,
                    foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                ))
                .disabled(isBusy)
                .accessibilityHint("Checking your account for newer toDōs.")
            }
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var isBusy: Bool {
        isRefreshing || syncCoordinator.syncActivityState == .activating || syncCoordinator.syncActivityState == .syncing
    }

    private var canRefresh: Bool {
        syncCoordinator.effectiveSyncMode == .syncEverywhere && authStore.isAuthenticated
    }

    private var statusTitle: String {
        if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            return String(localized: "Sign In Needed")
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return String(localized: "Getting Ready")
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return String(localized: "Active")
        }

        switch syncCoordinator.syncActivityState {
        case .idle, .synced:
            return String(localized: "Active")
        case .activating:
            return String(localized: "Getting Ready")
        case .syncing:
            return syncCoordinator.currentSyncPhase?.title ?? String(localized: "Syncing")
        case .failed:
            return String(localized: "Sync Failed")
        }
    }

    private var statusDetail: String {
        if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            return String(localized: "Sign in to activate toDō Sync on this Mac.")
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return String(
                format: String(localized: "%@ selected. Currently using %@."),
                syncCoordinator.preferredSyncMode.title,
                syncCoordinator.effectiveSyncMode.title
            )
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return String(
                format: String(localized: "toDō is using %@."),
                syncCoordinator.effectiveSyncMode.title
            )
        }

        switch syncCoordinator.syncActivityState {
        case .idle, .synced:
            return syncCoordinator.lastSuccessfulSyncAt.map(lastSyncMessage)
                ?? String(localized: "toDō Sync is on and ready.")
        case .activating:
            return syncCoordinator.currentSyncPhase?.detail
                ?? String(localized: "Getting this device ready.")
        case .syncing:
            return syncCoordinator.currentSyncPhase?.detail
                ?? String(localized: "Sharing changes and checking for updates.")
        case .failed:
            let phasePrefix = syncCoordinator.lastFailedSyncPhase.map { "\($0.title): " } ?? ""
            return syncCoordinator.lastSyncErrorMessage.map {
                String(format: String(localized: "The last sync did not finish. %@%@"), phasePrefix, $0)
            } ?? String(localized: "The last sync did not finish. Tap refresh to try again.")
        }
    }

    private var statusIcon: String {
        if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            return "person.crop.circle.badge.exclamationmark"
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return "arrow.triangle.2.circlepath"
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return "internaldrive.fill"
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return "clock.fill"
        case .activating, .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.icloud.fill"
        case .failed:
            return "exclamationmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
            return ToDoMacPalette.brandYellow
        }

        if syncCoordinator.preferredSyncMode != syncCoordinator.effectiveSyncMode {
            return ToDoMacPalette.brandBlue
        }

        if syncCoordinator.effectiveSyncMode != .syncEverywhere {
            return ToDoMacPalette.mutedInk
        }

        switch syncCoordinator.syncActivityState {
        case .idle:
            return ToDoMacPalette.mutedInk
        case .activating, .syncing:
            return ToDoMacPalette.brandBlue
        case .synced:
            return ToDoMacPalette.done
        case .failed:
            return ToDoMacPalette.urgent
        }
    }

    private func lastSyncMessage(_ date: Date) -> String {
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.locale = AppLocalization.displayLocale
        relativeFormatter.calendar = AppLocalization.displayCalendar
        relativeFormatter.unitsStyle = .full

        let timeFormatter = DateFormatter()
        timeFormatter.locale = AppLocalization.displayLocale
        timeFormatter.calendar = AppLocalization.displayCalendar
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return String(
            format: String(localized: "Last synced %@ at %@."),
            relativeFormatter.localizedString(for: date, relativeTo: .now),
            timeFormatter.string(from: date)
        )
    }

    private func refreshSync() {
        guard canRefresh, let userID = authStore.currentUserID, !isBusy else { return }

        isRefreshing = true
        Task { @MainActor in
            await syncCoordinator.flushLocalSync(userID: userID)
            isRefreshing = false
            NotificationCenter.default.post(name: .toDoMacRefreshMenuToDos, object: nil)
        }
    }
}

private struct ToDoMacNotificationStatusCard: View {
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ToDoMacIconBadge(systemName: statusIcon, color: statusColor, size: 14, dimension: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminder Alerts")
                        .font(.todoMacUI(15, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.ink)
                    Text(statusDetail)
                        .font(.todoMacUI(12, weight: .semibold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }

                Spacer()

                Text(statusTitle)
                    .font(.todoMacUI(13, weight: .bold))
                    .foregroundStyle(statusColor)
            }

            VStack(spacing: 10) {
                if !isAllowed {
                    Button {
                        Task { await notificationManager.requestAuthorizationFlow() }
                    } label: {
                        Label("Allow Reminders", systemImage: "bell.badge.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                }

                Button {
                    notificationManager.scheduleRefresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            }
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            await notificationManager.refreshAuthorizationStatus()
        }
    }

    private var isAllowed: Bool {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    private var statusTitle: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return String(localized: "Allowed")
        case .provisional:
            return String(localized: "Quiet")
        case .denied:
            return String(localized: "Blocked")
        case .notDetermined:
            return String(localized: "Not Set")
        default:
            return String(localized: "Unavailable")
        }
    }

    private var statusDetail: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return String(localized: "Due reminders can appear on this Mac.")
        case .provisional:
            return String(localized: "Reminders are allowed quietly on this Mac.")
        case .denied:
            return String(localized: "Open macOS notification settings to allow reminders.")
        case .notDetermined:
            return String(localized: "Allow reminders so due toDōs can notify you here.")
        default:
            return String(localized: "Notifications are not available on this Mac right now.")
        }
    }

    private var statusIcon: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return "bell.badge.fill"
        case .denied:
            return "bell.slash.fill"
        default:
            return "bell.fill"
        }
    }

    private var statusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional:
            return ToDoMacPalette.done
        case .denied:
            return ToDoMacPalette.urgent
        default:
            return ToDoMacPalette.brandYellow
        }
    }
}

private struct ToDoMacStatsPane: View {
    @AppStorage(AppPreferences.Keys.statsInsightsEnabled) private var statsInsightsEnabled = false
    @AppStorage(AppPreferences.Keys.appleIntelligenceEnabled) private var appleIntelligenceEnabled = false
    @State private var selectedStatsPage: Int? = 0
    @State private var hoveredStatsPage: Int?

    let toDos: [ToDo]

    private var activeToDos: [ToDo] { ToDo.active(from: toDos) }
    private var doneToDos: [ToDo] { toDos.filter { $0.lifecycleState == .done } }
    private var overdue: [ToDo] {
        activeToDos.filter { ($0.dueDate ?? .distantFuture) < .now }
    }
    private var timeSensitive: [ToDo] { ToDo.timeSensitive(from: activeToDos) }
    private var withNanoDos: [ToDo] {
        activeToDos.filter { !$0.nanoDos.isEmpty }
    }
    private var withTags: [ToDo] {
        activeToDos.filter { !$0.effectiveTags.isEmpty }
    }
    private var withNotes: [ToDo] {
        activeToDos.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var dueToday: [ToDo] {
        activeToDos.filter { $0.dueDate.map(Calendar.current.isDateInToday) ?? false }
    }
    private var scheduled: [ToDo] { activeToDos.filter { $0.dueDate != nil } }
    private var recurring: [ToDo] { activeToDos.filter(\.isRecurring) }
    private var completionRate: Int {
        let visible = toDos.filter { $0.lifecycleState != .trashed }.count
        guard visible > 0 else { return 0 }
        return Int((Double(doneToDos.count) / Double(visible) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statsMetricStrip

                ToDoMacActivityTracker(toDos: toDos)

                macStatsPages

                ToDoMacIntelligenceInsightsCard(
                    activeCount: activeToDos.count,
                    overdueCount: overdue.count,
                    dueTodayCount: dueToday.count,
                    timeSensitiveCount: timeSensitive.count,
                    completedCount: doneToDos.count,
                    completedWithNanoDosCount: withNanoDos.filter { $0.lifecycleState == .done }.count,
                    totalWithNanoDosCount: toDos.filter { $0.lifecycleState != .trashed && !$0.nanoDos.isEmpty }.count,
                    completedWithoutNanoDosCount: toDos.filter { $0.lifecycleState == .done && $0.nanoDos.isEmpty }.count,
                    totalWithoutNanoDosCount: toDos.filter { $0.lifecycleState != .trashed && $0.nanoDos.isEmpty }.count,
                    recurringCompletedLastThirtyDays: doneToDos.filter { toDo in
                        guard toDo.isRecurring else { return false }
                        let monthStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
                        return (toDo.completionActivityDate ?? toDo.syncUpdatedAt) >= monthStart
                    }.count,
                    isEnabled: $statsInsightsEnabled,
                    isAppleIntelligenceEnabled: $appleIntelligenceEnabled
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    private var statsMetricStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                statsMetric(title: "Due Today", value: dueToday.count, color: ToDoMacPalette.brandYellow, icon: "calendar")
                statsMetric(title: "Time-sensitive", value: timeSensitive.count, color: ToDoMacPalette.urgent, icon: "flame.fill")
                statsMetric(title: "Scheduled", value: scheduled.count, color: ToDoMacPalette.brandBlue, icon: "calendar.badge.clock")
                statsMetric(title: "Recurring", value: recurring.count, color: ToDoMacPalette.brandYellow, icon: "repeat")
            }

            LazyVGrid(
                columns: [
                    GridItem(.fixed(190), spacing: 14, alignment: .leading),
                    GridItem(.fixed(190), spacing: 14, alignment: .leading)
                ],
                alignment: .leading,
                spacing: 14
            ) {
                statsMetric(title: "Due Today", value: dueToday.count, color: ToDoMacPalette.brandYellow, icon: "calendar")
                statsMetric(title: "Time-sensitive", value: timeSensitive.count, color: ToDoMacPalette.urgent, icon: "flame.fill")
                statsMetric(title: "Scheduled", value: scheduled.count, color: ToDoMacPalette.brandBlue, icon: "calendar.badge.clock")
                statsMetric(title: "Recurring", value: recurring.count, color: ToDoMacPalette.brandYellow, icon: "repeat")
            }
        }
    }

    private func statsMetric(title: String, value: Int, color: Color, icon: String) -> some View {
        ToDoMacMetric(title: title, value: value, color: color, icon: icon)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macStatsPages: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                let pageWidth = max(proxy.size.width, 1)

                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            macStatsPage(index: 0, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Momentum",
                                value: "\(AppLocalization.numberString(completionRate))%",
                                detail: completionRate == 0 ? "Start completing toDōs to build a clearer trend." : "Completion rate across visible toDōs.",
                                icon: "speedometer",
                                color: ToDoMacPalette.done
                            )
                        }

                            macStatsPage(index: 1, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Workload Shape",
                                value: AppLocalization.numberString(activeToDos.count),
                                detail: "Active toDōs currently asking for attention.",
                                icon: "square.stack.3d.up.fill",
                                color: ToDoMacPalette.brandBlue
                            )
                        }

                            macStatsPage(index: 2, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Organization",
                                value: AppLocalization.numberString(withTags.count + withNotes.count + withNanoDos.count),
                                detail: "Active toDōs with notes, tags, or NanoDos attached.",
                                icon: "square.grid.2x2.fill",
                                color: ToDoMacPalette.brandYellow
                            )
                        }

                            macStatsPage(index: 3, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Completion Trends",
                                value: AppLocalization.numberString(doneToDos.count),
                                detail: "Completed toDōs in your current workspace.",
                                icon: "checkmark.seal.fill",
                                color: ToDoMacPalette.done
                            )
                        }

                            macStatsPage(index: 4, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Planning Accuracy",
                                value: AppLocalization.numberString(scheduled.count),
                                detail: "Scheduled toDōs currently on the board.",
                                icon: "calendar.badge.clock",
                                color: ToDoMacPalette.brandBlue
                            )
                        }

                            macStatsPage(index: 5, width: pageWidth) {
                            ToDoMacStatsInsightCard(
                                title: "Pressure Signals",
                                value: AppLocalization.numberString(overdue.count + timeSensitive.count),
                                detail: "Overdue and time-sensitive items combined.",
                                icon: "flame.fill",
                                color: ToDoMacPalette.urgent,
                                detailLineLimit: 1
                            )
                        }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedStatsPage, anchor: .leading)
                    .onChange(of: selectedStatsPage) { _, page in
                        guard let page else { return }
                        withAnimation(.easeInOut(duration: 0.24)) {
                            scrollProxy.scrollTo(page, anchor: .leading)
                        }
                    }
                    .onAppear {
                        if let page = selectedStatsPage {
                            scrollProxy.scrollTo(page, anchor: .leading)
                        }
                    }
                }
            }
            .frame(height: 230)

            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { page in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedStatsPage = page
                        }
                    } label: {
                        Capsule()
                            .fill(page == (selectedStatsPage ?? 0) ? ToDoMacPalette.brandYellow : ToDoMacPalette.mutedInk.opacity(0.35))
                            .frame(width: page == (selectedStatsPage ?? 0) ? 22 : 7, height: 7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stats page \(page + 1) of 6")
                    .accessibilityAddTraits(page == (selectedStatsPage ?? 0) ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func macStatsPage<Content: View>(
        index: Int,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ToDoMacPalette.panel)

            content()
                .frame(maxWidth: 560)
                .padding(.horizontal, 52)

            HStack {
                statsPageArrow(
                    systemName: "chevron.left",
                    label: "Previous stats page",
                    isEnabled: index > 0,
                    isHovered: hoveredStatsPage == index
                ) {
                    selectStatsPage(index - 1)
                }

                Spacer(minLength: 0)

                statsPageArrow(
                    systemName: "chevron.right",
                    label: "Next stats page",
                    isEnabled: index < 5,
                    isHovered: hoveredStatsPage == index
                ) {
                    selectStatsPage(index + 1)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(width: width, height: 220)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onHover { isHovering in
            hoveredStatsPage = isHovering ? index : nil
        }
        .id(index)
    }

    private func statsPageArrow(
        systemName: String,
        label: String,
        isEnabled: Bool,
        isHovered: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.todoMacSymbol(17, weight: .semibold))
                .foregroundStyle(isHovered ? ToDoMacPalette.brandYellow : ToDoMacPalette.mutedInk)
                .frame(width: 34, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 0.52 : 0.20)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func selectStatsPage(_ page: Int) {
        guard (0..<6).contains(page) else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            selectedStatsPage = page
        }
    }

}

private struct ToDoMacActivityTracker: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let toDos: [ToDo]

    private let minimumWeekCount = 12
    private let targetCellSide: CGFloat = 24
    private let cellSpacing: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let weekCount = weekCount(for: proxy.size.width)
            let side = cellSide(for: proxy.size.width, weekCount: weekCount)
            let weeks = ToDoActivityTracker.grid(from: toDos, weekCount: weekCount)

            VStack(alignment: .leading, spacing: 14) {
                Text(String(format: String(localized: "Completion rhythm over the last %lld weeks."), Int64(weekCount)))
                    .font(.todoMacUI(14, weight: .medium))
                    .foregroundStyle(ToDoMacPalette.mutedInk)

                HStack(alignment: .bottom, spacing: cellSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(week) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(cellColor(for: day))
                                    .frame(width: side, height: side)
                                    .overlay { cellOverlay(for: day) }
                                    .help(dayHelp(for: day))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                HStack(spacing: 7) {
                    Text("Less")
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(cellColor(for: ToDoActivityDay(date: .now, completionCount: level)))
                            .frame(width: 11, height: 11)
                    }
                    Text("More")
                }
                .font(.todoMacUI(12, weight: .medium))
                .foregroundStyle(ToDoMacPalette.mutedInk.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // The adaptive grid keeps the cells square while filling a wide Mac window.
        .frame(height: 274)
        .padding(.vertical, 2)
    }

    private func cellColor(for day: ToDoActivityDay) -> Color {
        switch day.intensity {
        case 0: return ToDoMacPalette.raised.opacity(0.76)
        case 1: return ToDoMacPalette.brandBlue.opacity(0.28)
        case 2: return ToDoMacPalette.brandBlue.opacity(0.48)
        case 3: return ToDoMacPalette.brandBlue.opacity(0.72)
        default: return ToDoMacPalette.brandBlue
        }
    }

    @ViewBuilder
    private func cellOverlay(for day: ToDoActivityDay) -> some View {
        if differentiateWithoutColor {
            let opacity = day.completionCount == 0 ? 0.14 : 0.5
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(ToDoMacPalette.ink.opacity(opacity), lineWidth: 1)
        }
    }

    private func dayHelp(for day: ToDoActivityDay) -> String {
        String(localized: "\(day.completionCount) completed on \(day.date.formatted(.dateTime.month(.abbreviated).day()))")
    }

    private func weekCount(for width: CGFloat) -> Int {
        let availableWidth = max(width, targetCellSide)
        let estimatedCount = Int(ceil((availableWidth + cellSpacing) / (targetCellSide + cellSpacing)))
        return max(minimumWeekCount, estimatedCount)
    }

    private func cellSide(for width: CGFloat, weekCount: Int) -> CGFloat {
        let spacing = CGFloat(max(weekCount - 1, 0)) * cellSpacing
        return max(8, (width - spacing) / CGFloat(max(weekCount, 1)))
    }
}

private struct ToDoMacSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ToDoMacSectionHeader(title: title)

            VStack(spacing: 12) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}

private struct ToDoMacSettingsRow: View {
    let title: String
    let value: String
    let systemName: String

    var body: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(systemName: systemName, color: badgeColor, size: 14, dimension: 34)

            Text(title)
                .font(.todoMacUI(15, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)

            Spacer()

            Text(value)
                .font(.todoMacUI(14, weight: .bold))
                .foregroundStyle(ToDoMacPalette.mutedInk)
        }
        .padding(14)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var badgeColor: Color {
        if systemName.contains("trash") {
            return ToDoMacPalette.urgent
        }
        if systemName.contains("bolt") || systemName.contains("cloud") {
            return ToDoMacPalette.brandBlue
        }
        return ToDoMacPalette.brandYellow
    }
}

private struct ToDoMacStatsInsightCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color
    var detailLineLimit: Int?

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                ToDoMacIconBadge(systemName: icon, color: color, size: 18, dimension: 46)

                Text(title)
                    .font(.todoMacDisplay(28))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
            }

            Text(value)
                .font(.todoMacDisplay(36))
                .foregroundStyle(color)

            Text(detail)
                .font(.todoMacUI(14))
                .foregroundStyle(ToDoMacPalette.mutedInk)
                .lineLimit(detailLineLimit)
                .minimumScaleFactor(detailLineLimit == nil ? 1 : 0.88)
                .allowsTightening(detailLineLimit != nil)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 560, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

private struct ToDoMacIntelligenceInsightsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    let activeCount: Int
    let overdueCount: Int
    let dueTodayCount: Int
    let timeSensitiveCount: Int
    let completedCount: Int
    let completedWithNanoDosCount: Int
    let totalWithNanoDosCount: Int
    let completedWithoutNanoDosCount: Int
    let totalWithoutNanoDosCount: Int
    let recurringCompletedLastThirtyDays: Int
    @Binding var isEnabled: Bool
    @Binding var isAppleIntelligenceEnabled: Bool

    @State private var generatedSummary: String?
    @State private var isGenerating = false
    @State private var animateGlow = false
    @State private var orbOneOffset = CGSize(width: 150, height: -72)
    @State private var orbTwoOffset = CGSize(width: -180, height: 170)
    @State private var orbOneOpacity = 0.16
    @State private var orbTwoOpacity = 0.12
    @State private var backgroundShift: CGFloat = -0.16

    private let supportURL = URL(string: "https://support.apple.com/en-us/121115")!

    var body: some View {
        ZStack(alignment: .topTrailing) {
            insightBackground
            decorativeOrbs

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: isEnabled ? "sparkles" : "lock.open.rotation")
                        .font(.todoMacUI(22, weight: .heavy))
                        .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
                        .frame(width: 52, height: 52)
                        .background(ToDoMacPalette.brandBlue, in: Circle())
                        .shadow(
                            color: ToDoMacPalette.brandBlue.opacity(isEnabled ? 0.48 : 0.2),
                            radius: isEnabled ? 18 : 8,
                            y: 8
                        )
                        .scaleEffect(animateGlow ? 1.04 : 1)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(isEnabled ? "Insights Unlocked" : "Private Insights")
                            .font(.todoMacDisplay(26))
                            .tracking(0.7)
                            .foregroundStyle(ToDoMacPalette.ink)

                        Text("Built for you, processed on this Mac.")
                            .font(.todoMacUI(14, weight: .bold))
                            .foregroundStyle(ToDoMacPalette.brandBlue)

                        Text("Your patterns stay private. Insights simply help you see what deserves attention next.")
                            .font(.todoMacUI(13, weight: .medium))
                            .foregroundStyle(ToDoMacPalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 10)

                    if isEnabled {
                        Toggle("Insights", isOn: $isEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(ToDoMacPalette.brandBlue)
                    }
                }

                if isEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        formattedInsight
                        insightMetricRow(title: "With NanoDos", value: completionRateWithNanoDos, systemName: "checklist")
                        insightMetricRow(title: "Without NanoDos", value: completionRateWithoutNanoDos, systemName: "list.bullet")
                        insightMetricRow(title: "Recurring Done 30 Days", value: AppLocalization.numberString(recurringCompletedLastThirtyDays), systemName: "repeat")
                        appleIntelligenceBlock
                    }
                } else {
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8)) {
                            isEnabled = true
                            animateGlow = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                            Text("Unlock Insights")
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(
                        color: ToDoMacPalette.brandBlue,
                        foreground: ToDoMacPalette.actionForeground(for: colorScheme)
                    ))
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(ToDoMacPalette.brandBlue.opacity(isEnabled ? 0.45 : 0.24), lineWidth: 1)
        }
        .shadow(color: ToDoMacPalette.brandBlue.opacity(isEnabled ? 0.18 : 0.08), radius: isEnabled ? 24 : 14, y: isEnabled ? 14 : 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                animateGlow = true
                backgroundShift = 0.2
            }
        }
        .task {
            guard !reduceMotion else { return }
            await runOrbAnimationLoop()
        }
        .task(id: generationID) {
            await refreshSummary()
        }
    }

    private var insightBackground: some View {
        LinearGradient(
            colors: [
                ToDoMacPalette.panel,
                ToDoMacPalette.brandBlue.opacity(isEnabled ? 0.18 : 0.1),
                ToDoMacPalette.done.opacity(isEnabled ? 0.14 : 0.06)
            ],
            startPoint: UnitPoint(x: backgroundShift, y: 0),
            endPoint: UnitPoint(x: 1.0 - backgroundShift, y: 1)
        )
    }

    private var decorativeOrbs: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ToDoMacPalette.brandBlue.opacity(orbOneOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: animateGlow ? 1 : 8)
                .offset(orbOneOffset)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [ToDoMacPalette.done.opacity(orbTwoOpacity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: animateGlow ? 1 : 7)
                .offset(orbTwoOffset)
        }
        .allowsHitTesting(false)
    }

    private func runOrbAnimationLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 5.2)) {
                orbOneOffset = CGSize(width: CGFloat.random(in: 100...210), height: CGFloat.random(in: -90 ... -25))
                orbTwoOffset = CGSize(width: CGFloat.random(in: -230 ... -140), height: CGFloat.random(in: 120...220))
                orbOneOpacity = Double.random(in: 0.1...0.2)
                orbTwoOpacity = Double.random(in: 0.08...0.16)
            }
        }
    }

    private var completionRateWithNanoDos: String {
        let value = totalWithNanoDosCount == 0 ? 0 : Int((Double(completedWithNanoDosCount) / Double(totalWithNanoDosCount) * 100).rounded())
        return "\(value)%"
    }

    private var completionRateWithoutNanoDos: String {
        let value = totalWithoutNanoDosCount == 0 ? 0 : Int((Double(completedWithoutNanoDosCount) / Double(totalWithoutNanoDosCount) * 100).rounded())
        return "\(value)%"
    }

    private func insightMetricRow(title: LocalizedStringKey, value: String, systemName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.todoMacUI(14, weight: .bold))
                .foregroundStyle(ToDoMacPalette.brandBlue)
                .frame(width: 30, height: 30)
                .background(ToDoMacPalette.brandBlue.opacity(0.12), in: Circle())

            Text(title)
                .font(.todoMacUI(14, weight: .semibold))
                .foregroundStyle(ToDoMacPalette.ink)

            Spacer(minLength: 12)

            Text(value)
                .font(.todoMacUI(17, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)
        }
    }

    private var appleIntelligenceBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isAppleIntelligenceEnabled ? "apple.intelligence" : "apple.intelligence.badge.xmark")
                    .font(.todoMacUI(17, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ToDoMacPalette.ink, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Intelligence")
                        .font(.todoMacDisplay(22))
                        .tracking(0.7)
                        .foregroundStyle(ToDoMacPalette.ink)

                    Text("Let toDō help summarize, organize, and surface what matters using Apple Intelligence when available.")
                        .font(.todoMacUI(13, weight: .medium))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Toggle("Use Apple Intelligence", isOn: $isAppleIntelligenceEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(ToDoMacPalette.brandBlue)
                    .disabled(!AppleIntelligenceService.isAvailable)
            }

            Text("Designed with privacy at the center. Supported features use Apple Intelligence when available without making AI required for toDō.")
                .font(.todoMacUI(12, weight: .medium))
                .foregroundStyle(ToDoMacPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if !AppleIntelligenceService.isAvailable {
                Button {
                    openURL(supportURL)
                } label: {
                    HStack(spacing: 8) {
                        Text("Apple Intelligence is not available on this Mac yet.")
                        Image(systemName: "arrow.right")
                    }
                    .font(.todoMacUI(12, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.brandBlue)
                }
                .buttonStyle(.plain)
            } else if isAppleIntelligenceEnabled {
                Label(
                    isGenerating ? "Apple Intelligence is reviewing your patterns..." : "Apple Intelligence is on.",
                    systemImage: isGenerating ? "sparkles" : "checkmark.seal.fill"
                )
                .font(.todoMacUI(12, weight: .bold))
                .foregroundStyle(ToDoMacPalette.brandBlue)
            }
        }
        .padding(14)
        .background(ToDoMacPalette.raised.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ToDoMacPalette.brandBlue.opacity(0.18), lineWidth: 1)
        }
    }

    private var deterministicSummary: String {
        if overdueCount > 0 {
            return String(format: String(localized: "%@ overdue toDōs are creating the clearest pressure. Resolve or reschedule one before adding more."), AppLocalization.numberString(overdueCount))
        }
        if dueTodayCount > 0 {
            return String(format: String(localized: "%@ toDōs are due today. Start with the one that unlocks the most progress."), AppLocalization.numberString(dueTodayCount))
        }
        return String(localized: "Your workload is steady. Choose one active toDō and move it forward.")
    }

    private var displayedSummary: String {
        (generatedSummary ?? deterministicSummary)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
    }

    @ViewBuilder
    private var formattedInsight: some View {
        if let sections = insightSections(from: displayedSummary) {
            VStack(alignment: .leading, spacing: 12) {
                macInsightTextBlock(title: "Summary", text: sections.summary, tint: ToDoMacPalette.brandBlue)
                macInsightTextBlock(title: "Next move", text: sections.nextMove, tint: ToDoMacPalette.brandYellow)
            }
        } else {
            Text(displayedSummary)
                .font(.todoMacUI(16, weight: .semibold))
                .foregroundStyle(ToDoMacPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func macInsightTextBlock(title: LocalizedStringKey, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.todoMacBodyStrong(14, relativeTo: .subheadline))
                .foregroundStyle(tint)

            Text(text)
                .font(.todoMacBody(15, relativeTo: .body))
                .foregroundStyle(ToDoMacPalette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(colorScheme == .dark ? 0.14 : 0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        }
    }

    private func insightSections(from insight: String) -> (summary: String, nextMove: String)? {
        let cleaned = insight
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let summaryRange = cleaned.range(of: "Summary:", options: [.caseInsensitive]),
              let nextMoveRange = cleaned.range(of: "Next move:", options: [.caseInsensitive]),
              summaryRange.upperBound <= nextMoveRange.lowerBound else { return nil }

        let summary = cleaned[summaryRange.upperBound..<nextMoveRange.lowerBound]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let nextMove = cleaned[nextMoveRange.upperBound...]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        guard !summary.isEmpty, !nextMove.isEmpty else { return nil }

        return (summary, nextMove)
    }

    private var generationID: String {
        "\(isEnabled)-\(isAppleIntelligenceEnabled)-\(activeCount)-\(overdueCount)-\(dueTodayCount)-\(timeSensitiveCount)-\(completedCount)"
    }

    @MainActor
    private func refreshSummary() async {
        guard isEnabled, isAppleIntelligenceEnabled, AppleIntelligenceService.isAvailable else {
            generatedSummary = nil
            isGenerating = false
            return
        }

        isGenerating = true
        generatedSummary = await AppleIntelligenceService.summarize(
            AppleIntelligenceSummaryInput(
                activeCount: activeCount,
                overdueCount: overdueCount,
                dueTodayCount: dueTodayCount,
                timeSensitiveCount: timeSensitiveCount,
                completedLastSevenDaysCount: completedCount,
                staleCount: 0,
                focusPressureScore: min((overdueCount * 4) + (timeSensitiveCount * 3) + (dueTodayCount * 2) + activeCount, 100),
                strongestDeterministicInsight: deterministicSummary
            ),
            isEnabled: true
        )
        isGenerating = false
    }
}

private struct ToDoMacChoiceButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let systemName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: systemName)
                    .font(.todoMacSymbol(13, weight: .heavy))
                    .foregroundStyle(isSelected ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.mutedInk)
                    .frame(width: 31, height: 31)
                    .background(isSelected ? color : ToDoMacPalette.panel, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.todoMacDisplay(20))
                        .tracking(0.65)
                        .foregroundStyle(isSelected ? ToDoMacPalette.ink : ToDoMacPalette.mutedInk)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.todoMacUI(11, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(
                (isSelected ? color.opacity(colorScheme == .dark ? 0.22 : 0.17) : ToDoMacPalette.raised),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.82) : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ToDoMacAppearanceChoiceButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let systemName: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.todoMacSymbol(18, weight: .heavy))
                    .foregroundStyle(isSelected ? ToDoMacPalette.actionForeground(for: colorScheme) : ToDoMacPalette.mutedInk)

                Text(title)
                    .font(.todoMacUI(13, weight: .bold))
                    .foregroundStyle(isSelected ? ToDoMacPalette.ink : ToDoMacPalette.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(.horizontal, 8)
            .background(
                isSelected ? color.opacity(colorScheme == .dark ? 0.22 : 0.17) : ToDoMacPalette.raised,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.82) : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ToDoMacFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(for: subviews, in: width)
        return CGSize(width: width, height: rows.reduce(CGFloat.zero) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * rowSpacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, in width: CGFloat) -> [CGSize] {
        guard width > 0 else {
            let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return [CGSize(width: width, height: height)]
        }

        var rows: [CGSize] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = currentWidth == 0 ? size.width : currentWidth + spacing + size.width
            if proposedWidth > width, currentWidth > 0 {
                rows.append(CGSize(width: currentWidth, height: currentHeight))
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if currentWidth > 0 || rows.isEmpty {
            rows.append(CGSize(width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct ToDoMacWindowRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let toDo: ToDo
    let isSelected: Bool
    let canRemove: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .strokeBorder(isSelected ? ToDoMacPalette.brandYellow : ToDoMacPalette.mutedInk.opacity(0.45), lineWidth: 3)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 5) {
                Text(toDo.task)
                    .font(.todoMacUI(18, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(2)
                Text(toDo.dueDate.map(AppLocalization.dateTimeString) ?? toDo.reminderIntent.title)
                    .font(.todoMacUI(12))
                    .foregroundStyle(ToDoMacPalette.mutedInk)

                if !attributeChips.isEmpty {
                    ToDoMacFlowLayout(spacing: 6, rowSpacing: 6) {
                        ForEach(attributeChips) { chip in
                            ToDoMacRowAttributePill(chip: chip)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onSelect)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onComplete) {
                Image(systemName: "checkmark")
                    .font(.todoMacSymbol(23, weight: .heavy))
                    .frame(width: 58, height: 58)
            }
            .accessibilityLabel("Mark toDō done")
            .tint(ToDoMacPalette.done)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canRemove {
                Button(role: .destructive, action: onTrash) {
                    Image(systemName: "trash")
                        .font(.todoMacSymbol(23, weight: .heavy))
                        .frame(width: 58, height: 58)
                }
                .accessibilityLabel("Move toDō to trash")
                .tint(ToDoMacPalette.urgent)
            }
        }
        .contextMenu {
            Button(action: onComplete) {
                Label("Mark toDō done", systemImage: "checkmark.circle")
            }

            if canRemove {
                Button(role: .destructive, action: onTrash) {
                    Label("Move toDō to trash", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var attributeChips: [ToDoMacRowAttributeChip] {
        var chips: [ToDoMacRowAttributeChip] = []

        if let recurrenceSummary = toDo.recurrenceSummary {
            chips.append(.init(title: recurrenceSummary, systemName: "arrow.triangle.2.circlepath", color: ToDoMacPalette.brandBlue))
        }

        if !toDo.nanoDos.isEmpty {
            let completed = toDo.nanoDos.filter(\.isDone).count
            let total = toDo.nanoDos.count
            let title = "\(AppLocalization.numberString(completed))/\(AppLocalization.numberString(total)) NanoDos"
            chips.append(.init(title: title, systemName: "checklist", color: ToDoMacPalette.done))
        }

        let visibleTags = Array(toDo.effectiveTags.prefix(2))
        for tag in visibleTags {
            chips.append(.init(title: tag.displayName, systemName: "tag.fill", color: ToDoMacPalette.brandBlue))
        }

        if toDo.effectiveTags.count > visibleTags.count {
            let remaining = toDo.effectiveTags.count - visibleTags.count
            chips.append(.init(title: "+\(AppLocalization.numberString(remaining))", systemName: "tag", color: ToDoMacPalette.mutedInk))
        }

        if toDo.hasLocationReminder {
            chips.append(.init(title: toDo.locationReminderLabel ?? toDo.locationReminderTrigger.title, systemName: "location.fill", color: ToDoMacPalette.brandBlue))
        }

        return chips
    }

    private var isOverdue: Bool {
        guard let dueDate = toDo.dueDate else { return false }
        return dueDate < .now
    }

    private var rowBackground: Color {
        if isOverdue {
            return ToDoMacPalette.urgent.opacity(colorScheme == .dark ? 0.22 : 0.12)
        }
        return isSelected ? ToDoMacPalette.raised : ToDoMacPalette.panel
    }
}

private struct ToDoMacRowAttributeChip: Identifiable {
    let title: String
    let systemName: String
    let color: Color
    var foreground: Color? = nil
    var background: Color? = nil

    var id: String {
        "\(systemName)-\(title)"
    }
}

private struct ToDoMacRowAttributePill: View {
    let chip: ToDoMacRowAttributeChip

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: chip.systemName)
                .font(.todoMacSymbol(9, weight: .heavy))
            Text(chip.title)
                .font(.todoMacUI(10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(chip.foreground ?? chip.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(chip.background ?? chip.color.opacity(0.14), in: Capsule())
    }
}

private struct ToDoMacCompactRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let item: ToDoMacMenuItem
    let isCompleting: Bool
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ToDoMacIconBadge(
                        systemName: item.reminderIntent == .timeSensitive ? "flame.fill" : "clock.fill",
                        color: reminderColor,
                        size: 13,
                        dimension: 30
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.task)
                            .font(.todoMacUI(15, weight: .bold))
                            .foregroundStyle(ToDoMacPalette.ink)
                            .italic(isCompleting)
                            .strikethrough(isCompleting, color: ToDoMacPalette.ink.opacity(0.75))
                            .lineLimit(1)
                        if let dueDate = item.dueDate {
                            Text(AppLocalization.dateTimeString(dueDate))
                                .font(.todoMacUI(11))
                                .foregroundStyle(ToDoMacPalette.mutedInk)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.task)
            .accessibilityHint("Opens this toDō in the main app.")

            Button(action: onComplete) {
                Image(systemName: "checkmark")
                    .font(.todoMacSymbol(15, weight: .heavy))
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.done, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            .disabled(isCompleting)
            .accessibilityLabel(isCompleting ? "Completing toDō" : "Mark toDō done")
        }
        .padding(12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .trailing) {
            if isCompleting {
                Text("Done")
                    .font(.todoMacDisplay(16))
                    .tracking(0.6)
                    .foregroundStyle(ToDoMacPalette.done)
                    .padding(.trailing, 58)
                    .transition(.opacity.combined(with: .offset(x: 8)))
            }
        }
        .saturation(isCompleting ? 0.15 : 1)
        .opacity(isCompleting ? 0.72 : 1)
        .scaleEffect(isCompleting ? 0.985 : 1)
    }

    private var reminderColor: Color {
        item.reminderIntent == .timeSensitive ? ToDoMacPalette.urgent : ToDoMacPalette.brandYellow
    }

    private var rowBackground: Color {
        isCompleting ? ToDoMacPalette.done.opacity(0.22) : ToDoMacPalette.panel
    }
}

private struct ToDoMacMetric: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let title: String
    let value: Int
    let color: Color
    let icon: String
    var isCompact = false

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        ToDoMacIconBadge(systemName: icon, color: color, size: 11, dimension: 22)
                        Text(AppLocalization.numberString(value))
                            .font(.todoMacDisplay(24))
                            .foregroundStyle(ToDoMacPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Text(title)
                        .font(.todoMacUI(10, weight: .bold))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ToDoMacIconBadge(systemName: icon, color: color, size: 12, dimension: 24)
                        Text(title)
                            .font(.todoMacUI(11, weight: .bold))
                            .foregroundStyle(ToDoMacPalette.mutedInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                    }
                    Text(AppLocalization.numberString(value))
                        .font(.todoMacDisplay(30))
                        .foregroundStyle(ToDoMacPalette.ink)
                }
            }
        }
        // Keep Home momentum cards close to their content instead of allowing
        // each grid item to paint a wide, mostly empty trailing area.
        // A compact Home metric is content-sized. Letting the grid propose its
        // full column width turns the trailing 70-80% into empty decoration on
        // wide Mac windows.
        .frame(width: isCompact ? 176 : nil, alignment: .leading)
        .padding(.horizontal, isCompact ? 9 : 12)
        .padding(.vertical, isCompact ? 7 : 12)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if differentiateWithoutColor {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        ToDoMacPalette.ink.opacity(0.72),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                    )
            }
        }
    }
}

private struct ToDoMacAttributeCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ToDoMacIconBadge(systemName: icon, color: color, size: 16, dimension: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.todoMacDisplay(18))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                Text(value)
                    .font(.todoMacUI(15, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ToDoMacPrimaryButtonStyle: ButtonStyle {
    let color: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.todoMacDisplay(19))
            .tracking(0.8)
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ToDoMacSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.todoMacDisplay(19))
            .tracking(0.8)
            .foregroundStyle(ToDoMacPalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ToDoMacPalette.raised.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct ToDoMacIconButtonStyle: ButtonStyle {
    let color: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
