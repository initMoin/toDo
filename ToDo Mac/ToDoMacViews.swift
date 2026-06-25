import SwiftData
import SwiftUI
import UserNotifications

private enum ToDoMacPalette {
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

private enum ToDoMacPreferenceKeys {
    static let appAppearanceMode = "appAppearanceMode"
    static let doneSwipePrimaryAction = "doneSwipePrimaryAction"
    static let syncMode = "syncMode"
}

enum ToDoMacAppearanceMode: String {
    case system
    case light
    case dark
}

private extension Font {
    static func todoMacBrand(_ size: CGFloat) -> Font { .custom("Cal Sans", size: size) }
    static func todoMacDisplay(_ size: CGFloat) -> Font { .custom("Bebas Neue", size: size) }
    static func todoMacUI(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font { .custom("Jura", size: size).weight(weight) }
    static func todoMacEntry(_ size: CGFloat, weight: Font.Weight = .medium) -> Font { .custom("Aleo", size: size).weight(weight) }
}

private struct ToDoMacIconBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let color: Color
    var size: CGFloat = 14
    var dimension: CGFloat = 34

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(ToDoMacPalette.actionForeground(for: colorScheme))
            .frame(width: dimension, height: dimension)
            .background(color, in: Circle())
    }
}

private struct ToDoMacSectionHeader: View {
    let title: String
    var tint: Color = ToDoMacPalette.brandYellow

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(tint)
                .frame(width: 5, height: 25)
            Text(title)
                .font(.todoMacDisplay(30))
                .tracking(0.6)
                .foregroundStyle(ToDoMacPalette.ink)
        }
    }
}

struct ToDoMacMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\ToDo.createdAt, order: .reverse)]) private var toDos: [ToDo]
    @State private var quickTask = ""

    private var activeToDos: [ToDo] {
        toDos.filter { $0.lifecycleState == .active }
    }

    private var dueSoon: [ToDo] {
        let upperBound = Date.now.addingTimeInterval(60 * 60 * 24)
        return activeToDos
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return dueDate <= upperBound
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            quickAdd
            summaryGrid
            upcomingList
            footerActions
        }
        .padding(22)
        .frame(width: 390)
        .background(ToDoMacPalette.background)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("toDō")
                .font(.todoMacBrand(34))
                .foregroundStyle(ToDoMacPalette.ink)
            Spacer()
            Text(AppLocalization.dateString(.now).uppercased())
                .font(.todoMacDisplay(18))
                .foregroundStyle(ToDoMacPalette.mutedInk)
        }
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What matters now?")
                .font(.todoMacUI(20, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)

            HStack(spacing: 10) {
                TextField("what toDō today?", text: $quickTask)
                    .textFieldStyle(.plain)
                    .font(.todoMacEntry(17))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit(addQuickToDo)

                Button(action: addQuickToDo) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .heavy))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .disabled(quickTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            ToDoMacMetric(title: "Active", value: activeToDos.count, color: ToDoMacPalette.brandBlue, icon: "bolt.fill")
            ToDoMacMetric(title: "Due soon", value: dueSoon.count, color: ToDoMacPalette.brandYellow, icon: "clock.fill")
            ToDoMacMetric(title: "Done", value: toDos.filter { $0.lifecycleState == .done }.count, color: ToDoMacPalette.done, icon: "checkmark.circle.fill")
        }
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up Next")
                .font(.todoMacDisplay(22))
                .foregroundStyle(ToDoMacPalette.ink)

            if dueSoon.isEmpty {
                Text("Nothing needs the front row right now.")
                    .font(.todoMacUI(13))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                ForEach(dueSoon.prefix(4)) { toDo in
                    ToDoMacCompactRow(toDo: toDo, onComplete: { complete(toDo) }, onTrash: { trash(toDo) })
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button {
                openWindow(id: "todo-mac-main")
            } label: {
                Label("Open toDō", systemImage: "arrow.up.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

            Button {
                openWindow(id: "todo-mac-main")
            } label: {
                Label("New toDō", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        }
    }

    private func addQuickToDo() {
        let task = quickTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }
        modelContext.insert(ToDo(task: task))
        try? modelContext.save()
        refreshMacSurfaces()
        quickTask = ""
    }

    private func complete(_ toDo: ToDo) {
        toDo.transition(to: .done)
        try? modelContext.save()
        refreshMacSurfaces()
    }

    private func trash(_ toDo: ToDo) {
        toDo.trashedAt = .now
        toDo.transition(to: .trashed)
        try? modelContext.save()
        refreshMacSurfaces()
    }

    private func refreshMacSurfaces() {
        NotificationManager.shared.scheduleRefresh()
        WidgetSnapshotService.shared.writeSnapshot(from: modelContext)
        SyncCoordinator.shared.scheduleLocalSync()
    }
}

struct ToDoMacWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: [SortDescriptor(\ToDo.createdAt, order: .reverse)]) private var toDos: [ToDo]
    @Query(sort: [SortDescriptor(\Tag.name)]) private var tags: [Tag]
    @State private var screen: ToDoMacScreen = .home
    @State private var selectedToDo: ToDo?
    @State private var editorMode: ToDoMacEditorMode?

    private var activeToDos: [ToDo] {
        toDos.filter { $0.lifecycleState == .active }
    }

    private var dueSoon: [ToDo] {
        let upperBound = Date.now.addingTimeInterval(60 * 60 * 24)
        return activeToDos
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return dueDate <= upperBound
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
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
        content
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ToDoMacPalette.background)
        .animation(macTransitionAnimation, value: screen)
        .animation(macTransitionAnimation, value: selectedToDo?.id)
        .animation(macTransitionAnimation, value: editorMode?.id)
    }

    private var macTransitionAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.24)
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .home:
            homePane
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        case .allToDos:
            if selectedToDo == nil && editorMode == nil {
                listPane
                    .frame(maxWidth: 760)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                HStack(spacing: 22) {
                    listPane
                    if let editorMode {
                        ToDoMacEditorPane(
                            mode: editorMode,
                            availableTags: tags,
                            onCancel: { self.editorMode = nil },
                            onSave: { savedToDo in
                                selectedToDo = savedToDo
                                self.editorMode = nil
                                refreshMacSurfaces()
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else if let selectedToDo {
                        ToDoMacDetailPane(
                            toDo: selectedToDo,
                            onEdit: { editorMode = .edit(selectedToDo) },
                            onComplete: { complete(selectedToDo) },
                            onTrash: { trash(selectedToDo) },
                            onClose: { self.selectedToDo = nil }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(macTransitionAnimation, value: selectedToDo?.id)
            }
        case .settings:
            ToDoMacSettingsPane(
                toDos: toDos,
                onBack: { withAnimation(macTransitionAnimation) { screen = .home } }
            )
            .frame(maxWidth: 880)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        case .stats:
            ToDoMacStatsPane(
                toDos: toDos,
                onBack: { withAnimation(macTransitionAnimation) { screen = .home } }
            )
            .frame(maxWidth: 880)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var homePane: some View {
        VStack(alignment: .leading, spacing: 24) {
            macHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                homeHero
                homeUpNext
                homeMomentum
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var macHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.dateString(.now).uppercased())
                    .font(.todoMacDisplay(18))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                Text("toDō")
                    .font(.todoMacBrand(52))
                    .foregroundStyle(ToDoMacPalette.ink)
            }
            Spacer()
            Button {
                withAnimation(macTransitionAnimation) { screen = .settings }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
        }
    }

    private var homeHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What matters now?")
                .font(.todoMacUI(25, weight: .bold))
                .foregroundStyle(ToDoMacPalette.ink)

            HStack(spacing: 12) {
                Button {
                    withAnimation(macTransitionAnimation) {
                        screen = .allToDos
                        selectedToDo = nil
                        editorMode = .create()
                    }
                } label: {
                    Label("New toDō", systemImage: "plus")
                        .frame(minWidth: 132)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

                Button {
                    withAnimation(macTransitionAnimation) {
                        screen = .allToDos
                        selectedToDo = nil
                    }
                } label: {
                    Label("See all toDōs", systemImage: "list.bullet")
                        .frame(minWidth: 150)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            }
        }
        .padding(22)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var homeUpNext: some View {
        VStack(alignment: .leading, spacing: 12) {
            ToDoMacSectionHeader(title: "Up Next")

            if dueSoon.isEmpty {
                Text("Nothing needs the front row right now.")
                    .font(.todoMacUI(14))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(dueSoon.prefix(3)) { toDo in
                    ToDoMacHomeReadOnlyRow(toDo: toDo)
                }
            }
        }
    }

    private var homeMomentum: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ToDoMacSectionHeader(title: "Momentum")
                Spacer()
                Button {
                    withAnimation(macTransitionAnimation) { screen = .stats }
                } label: {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ToDoMacMetric(title: "Active", value: activeToDos.count, color: ToDoMacPalette.brandBlue, icon: "bolt.fill")
                ToDoMacMetric(title: "Due soon", value: dueSoon.count, color: ToDoMacPalette.brandYellow, icon: "clock.fill")
                ToDoMacMetric(title: "Overdue", value: overdueCount, color: ToDoMacPalette.urgent, icon: "exclamationmark.circle.fill")
                ToDoMacMetric(title: "Time-sensitive", value: timeSensitiveCount, color: ToDoMacPalette.urgent, icon: "flame.fill")
                ToDoMacMetric(title: "Completed", value: completedCount, color: ToDoMacPalette.done, icon: "checkmark.circle.fill")
                    .gridCellColumns(2)
            }
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                Button {
                    if selectedToDo != nil {
                        withAnimation(macTransitionAnimation) { selectedToDo = nil }
                    } else if editorMode != nil {
                        withAnimation(macTransitionAnimation) { editorMode = nil }
                    } else {
                        withAnimation(macTransitionAnimation) { screen = .home }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 28, weight: .heavy))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.dateString(.now).uppercased())
                        .font(.todoMacDisplay(18))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                    Text("toDōs")
                        .font(.todoMacDisplay(40))
                        .foregroundStyle(ToDoMacPalette.ink)
                }
                Spacer()
                Button {
                    withAnimation(macTransitionAnimation) {
                        selectedToDo = nil
                        editorMode = .create()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .heavy))
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    if activeToDos.isEmpty {
                        Text("Nothing needs the front row right now.")
                            .font(.todoMacUI(15))
                            .foregroundStyle(ToDoMacPalette.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        ForEach(activeToDos) { toDo in
                            ToDoMacWindowRow(
                                toDo: toDo,
                                isSelected: selectedToDo?.id == toDo.id,
                                onSelect: {
                                    editorMode = nil
                                    selectedToDo = toDo
                                },
                                onComplete: { complete(toDo) },
                                onTrash: { trash(toDo) }
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 420, maxWidth: 520)
    }

    private func complete(_ toDo: ToDo) {
        toDo.transition(to: .done)
        try? modelContext.save()
        refreshMacSurfaces()
        if selectedToDo?.id == toDo.id { selectedToDo = nil }
    }

    private func trash(_ toDo: ToDo) {
        toDo.trashedAt = .now
        toDo.transition(to: .trashed)
        try? modelContext.save()
        refreshMacSurfaces()
        if selectedToDo?.id == toDo.id { selectedToDo = nil }
    }

    private func refreshMacSurfaces() {
        NotificationManager.shared.scheduleRefresh()
        WidgetSnapshotService.shared.writeSnapshot(from: modelContext)
        SyncCoordinator.shared.scheduleLocalSync()
    }
}

private enum ToDoMacScreen {
    case home
    case allToDos
    case settings
    case stats
}

private enum ToDoMacEditorMode: Identifiable {
    case create(UUID = UUID())
    case edit(ToDo)

    var id: String {
        switch self {
        case .create(let id):
            return "create-\(id.uuidString)"
        case .edit(let toDo):
            return "edit-\(toDo.id)"
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

    var existingToDo: ToDo? {
        if case .edit(let toDo) = self { return toDo }
        return nil
    }
}

private struct ToDoMacDetailPane: View {
    let toDo: ToDo
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onTrash: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Your toDō")
                    .font(.todoMacDisplay(34))
                    .foregroundStyle(ToDoMacPalette.brandYellow)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 30, weight: .heavy))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandBlue, foreground: .black))
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .heavy))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
            }

            Text(toDo.task)
                .font(.todoMacEntry(42, weight: .medium))
                .foregroundStyle(ToDoMacPalette.ink)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            HStack(spacing: 12) {
                ToDoMacAttributeCard(
                    title: toDo.dueDate == nil ? "Updated" : "Due",
                    value: AppLocalization.dateTimeString(toDo.dueDate ?? toDo.syncUpdatedAt),
                    icon: toDo.dueDate == nil ? "clock.arrow.circlepath" : "calendar.badge.clock",
                    color: ToDoMacPalette.brandYellow
                )
                ToDoMacAttributeCard(title: "Reminder", value: toDo.reminderIntent.title, icon: "bell.fill", color: reminderColor)
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

            if !toDo.tags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tags")
                        .font(.todoMacDisplay(22))
                        .foregroundStyle(ToDoMacPalette.mutedInk)

                    ToDoMacFlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(toDo.tags) { tag in
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
                        ForEach(toDo.nanoDos) { nanoDo in
                            HStack(spacing: 10) {
                                Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .heavy))
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
                ToDoMacAttributeCard(
                    title: "Location",
                    value: toDo.locationReminderLabel ?? toDo.locationReminderTrigger.title,
                    icon: "location.fill",
                    color: ToDoMacPalette.brandBlue
                )
            }

            Spacer()

            HStack(spacing: 14) {
                Button(action: onComplete) {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: .black))

                Button(action: onTrash) {
                    Label("Trash", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
            }
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var reminderColor: Color {
        switch toDo.reminderIntent {
        case .soft: ToDoMacPalette.mutedInk
        case .due: ToDoMacPalette.brandYellow
        case .timeSensitive: ToDoMacPalette.urgent
        }
    }
}

private struct ToDoMacNanoDoDraft: Identifiable, Equatable {
    let id = UUID()
    var existingID: PersistentIdentifier?
    var task: String
    var isDone: Bool
    var hasDueDate: Bool
    var dueDate: Date

    init(nanoDo: NanoDo? = nil) {
        existingID = nanoDo?.id
        task = nanoDo?.task ?? ""
        isDone = nanoDo?.isDone ?? false
        hasDueDate = nanoDo?.dueDate != nil
        dueDate = nanoDo?.dueDate ?? .now.addingTimeInterval(60 * 60)
    }
}

private struct ToDoMacEditorPane: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    let mode: ToDoMacEditorMode
    let availableTags: [Tag]
    let onCancel: () -> Void
    let onSave: (ToDo) -> Void

    @State private var task: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var reminderIntent: ToDoReminderIntent
    @State private var completeWhenAllNanoDosDone: Bool
    @State private var selectedTagIDs: Set<PersistentIdentifier>
    @State private var newTagName: String
    @State private var nanoDrafts: [ToDoMacNanoDoDraft]

    init(
        mode: ToDoMacEditorMode,
        availableTags: [Tag],
        onCancel: @escaping () -> Void,
        onSave: @escaping (ToDo) -> Void
    ) {
        self.mode = mode
        self.availableTags = availableTags
        self.onCancel = onCancel
        self.onSave = onSave

        let existing = mode.existingToDo
        _task = State(initialValue: existing?.task ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _hasDueDate = State(initialValue: existing?.dueDate != nil)
        _dueDate = State(initialValue: existing?.dueDate ?? .now.addingTimeInterval(60 * 60))
        _reminderIntent = State(initialValue: existing?.reminderIntent ?? .due)
        _completeWhenAllNanoDosDone = State(initialValue: existing?.completeWhenAllNanoDosDone ?? false)
        _selectedTagIDs = State(initialValue: Set(existing?.tags.map(\.id) ?? []))
        _newTagName = State(initialValue: "")
        _nanoDrafts = State(initialValue: existing?.nanoDos.map { ToDoMacNanoDoDraft(nanoDo: $0) } ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text(mode.title)
                    .font(.todoMacDisplay(34))
                    .tracking(0.8)
                    .foregroundStyle(ToDoMacPalette.brandYellow)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .heavy))
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editorSection("toDō") {
                        TextField("what toDō today?", text: $task, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(2...4)
                            .font(.todoMacEntry(30, weight: .medium))
                            .foregroundStyle(ToDoMacPalette.ink)
                            .padding(20)
                            .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    editorSection("Due + Reminder") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $hasDueDate) {
                                Label("Due date", systemImage: "calendar.badge.clock")
                                    .font(.todoMacUI(16, weight: .bold))
                            }
                            .toggleStyle(.switch)

                            if hasDueDate {
                                DatePicker("When", selection: $dueDate)
                                    .font(.todoMacUI(15, weight: .bold))
                                    .datePickerStyle(.compact)

                                HStack(spacing: 10) {
                                    ForEach(ToDoReminderIntent.allCases) { intent in
                                        Button {
                                            reminderIntent = intent
                                        } label: {
                                            Text(intent.title)
                                                .frame(maxWidth: .infinity)
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
                                        .font(.system(size: 15, weight: .heavy))
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
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
                                                .font(.system(size: 20, weight: .heavy))
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
                                                .font(.system(size: 14, weight: .heavy))
                                                .frame(width: 34, height: 34)
                                        }
                                        .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
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
                                    .frame(maxWidth: .infinity)
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
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Button(action: save) {
                Label(mode.existingToDo == nil ? "Create toDō" : "Save changes", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.done, foreground: .black))
        }
        .padding(26)
        .frame(minWidth: 440, maxWidth: 560, maxHeight: .infinity)
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
        if let existing = availableTags.first(where: { Tag.normalizeName($0.name) == normalized }) {
            if selectedTagIDs.count < ToDo.maxTagSelection {
                selectedTagIDs.insert(existing.id)
            }
        } else {
            let tag = Tag(name: rawName)
            modelContext.insert(tag)
            if selectedTagIDs.count < ToDo.maxTagSelection {
                selectedTagIDs.insert(tag.id)
            }
        }
        newTagName = ""
    }

    private func removeNanoDraft(_ draft: ToDoMacNanoDoDraft) {
        nanoDrafts.removeAll { $0.id == draft.id }
    }

    private func save() {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else { return }

        let savedToDo: ToDo
        if let existing = mode.existingToDo {
            savedToDo = existing
            existing.task = trimmedTask
            existing.notes = notes
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.reminderIntent = hasDueDate ? reminderIntent : .soft
            existing.completeWhenAllNanoDosDone = completeWhenAllNanoDosDone
            existing.setSelectedTags(selectedTags)
            reconcileNanoDos(for: existing)
            existing.markUpdated()
        } else {
            let toDo = ToDo(
                task: trimmedTask,
                notes: notes,
                dueDate: hasDueDate ? dueDate : nil,
                reminderIntent: hasDueDate ? reminderIntent : .soft,
                completeWhenAllNanoDosDone: completeWhenAllNanoDosDone
            )
            modelContext.insert(toDo)
            toDo.setSelectedTags(selectedTags)
            reconcileNanoDos(for: toDo)
            savedToDo = toDo
        }

        try? modelContext.save()
        onSave(savedToDo)
    }

    private var selectedTags: [Tag] {
        availableTags.filter { selectedTagIDs.contains($0.id) }
    }

    private func reconcileNanoDos(for toDo: ToDo) {
        let existingByID = Dictionary(uniqueKeysWithValues: toDo.nanoDos.map { ($0.id, $0) })
        var nextNanoDos: [NanoDo] = []
        var retainedIDs = Set<PersistentIdentifier>()

        for draft in nanoDrafts {
            let trimmedTask = draft.task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTask.isEmpty else { continue }

            let nanoDo: NanoDo
            if let existingID = draft.existingID, let existing = existingByID[existingID] {
                nanoDo = existing
                retainedIDs.insert(existingID)
            } else {
                nanoDo = NanoDo(task: trimmedTask, toDo: toDo)
                modelContext.insert(nanoDo)
            }

            nanoDo.task = trimmedTask
            nanoDo.isDone = draft.isDone
            nanoDo.dueDate = draft.hasDueDate ? draft.dueDate : nil
            nanoDo.toDo = toDo
            nextNanoDos.append(nanoDo)
        }

        for existing in toDo.nanoDos where !retainedIDs.contains(existing.id) && existingByID[existing.id] != nil {
            if !nextNanoDos.contains(where: { $0.id == existing.id }) {
                modelContext.delete(existing)
            }
        }

        toDo.nanoDos = nextNanoDos
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
                    .font(.todoMacUI(16, weight: .bold))
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
    let onBack: () -> Void

    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @AppStorage(ToDoMacPreferenceKeys.doneSwipePrimaryAction) private var removalActionRaw = ToDoMacRemovalAction.archive.rawValue
    @AppStorage(ToDoMacPreferenceKeys.appAppearanceMode) private var appearanceModeRaw = ToDoMacAppearanceMode.system.rawValue

    private var activeCount: Int { toDos.filter { $0.lifecycleState == .active }.count }
    private var archiveCount: Int { toDos.filter { $0.lifecycleState == .archived || $0.lifecycleState == .done }.count }
    private var trashCount: Int { toDos.filter { $0.lifecycleState == .trashed }.count }

    private var removalAction: ToDoMacRemovalAction {
        ToDoMacRemovalAction(rawValue: removalActionRaw) ?? .archive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToDoMacSurfaceHeader(title: "Settings", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                ToDoMacSettingsSection(title: "Account & Sync") {
                    ToDoMacAccountStatusCard()
                    ToDoMacSyncModeControl()
                    ToDoMacSettingsRow(title: "Local Active", value: AppLocalization.numberString(activeCount), systemName: "bolt.fill")
                }

                ToDoMacSettingsSection(title: "Behavior") {
                    HStack(spacing: 12) {
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
                    }

                    ToDoMacSettingsRow(title: "Current Default", value: removalAction.compactTitle, systemName: removalAction.systemImage)
                }

                ToDoMacSettingsSection(title: "Notifications") {
                    ToDoMacNotificationStatusCard()
                }

                ToDoMacSettingsSection(title: "Appearance") {
                    HStack(spacing: 12) {
                        ForEach(appearanceOptions, id: \.rawValue) { option in
                            ToDoMacChoiceButton(
                                title: appearanceTitle(for: option),
                                subtitle: appearanceSubtitle(for: option),
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
                }

                ToDoMacSettingsSection(title: "Manage Your Data") {
                    HStack(spacing: 12) {
                        ToDoMacMetric(title: "Archives", value: archiveCount, color: ToDoMacPalette.brandYellow, icon: "archivebox.fill")
                        ToDoMacMetric(title: "Trash", value: trashCount, color: ToDoMacPalette.urgent, icon: "trash.fill")
                    }
                }
            }
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var appearanceOptions: [ToDoMacAppearanceMode] {
        [.system, .light, .dark]
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

private struct ToDoMacAccountStatusCard: View {
    @EnvironmentObject private var authStore: ToDoMacAuthStore
    @Environment(\.colorScheme) private var colorScheme

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

            HStack(spacing: 10) {
                if authStore.isAuthenticated {
                    Button {
                        Task { await authStore.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.urgent, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                    .disabled(authStore.isAuthenticating)
                } else {
                    Button {
                        Task { await authStore.signInWithApple() }
                    } label: {
                        Label("Sign In with Apple", systemImage: "apple.logo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                    .disabled(authStore.isAuthenticating)

                    Button {
                        Task { await authStore.signInWithGoogle() }
                    } label: {
                        Label("Google", systemImage: "globe")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandBlue, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                    .disabled(authStore.isAuthenticating)
                }
            }
        }
        .padding(16)
        .background(ToDoMacPalette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var accountDetail: String {
        if authStore.isAuthenticated {
            if let provider = authStore.providerLabel {
                return String(format: String(localized: "Connected through %@."), provider)
            }
            return String(localized: "Connected and ready for toDō Sync.")
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

            HStack(spacing: 12) {
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
                        userID: authStore.currentUserID,
                        shouldTransferData: true
                    )
                    selectedMode = syncCoordinator.preferredSyncMode
                }
            }

            if syncCoordinator.preferredSyncMode == .syncEverywhere, !authStore.isAuthenticated {
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

            HStack(spacing: 10) {
                Button {
                    Task { await notificationManager.requestAuthorizationFlow() }
                } label: {
                    Label("Allow Reminders", systemImage: "bell.badge.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ToDoMacPrimaryButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))
                .disabled(isAllowed)

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
    let toDos: [ToDo]
    let onBack: () -> Void

    private var activeToDos: [ToDo] { toDos.filter { $0.lifecycleState == .active } }
    private var doneToDos: [ToDo] { toDos.filter { $0.lifecycleState == .done } }
    private var dueSoon: [ToDo] {
        let upperBound = Date.now.addingTimeInterval(60 * 60 * 24)
        return activeToDos.filter { ($0.dueDate ?? .distantFuture) <= upperBound }
    }
    private var overdue: [ToDo] {
        activeToDos.filter { ($0.dueDate ?? .distantFuture) < .now }
    }
    private var timeSensitive: [ToDo] {
        activeToDos.filter { $0.reminderIntent == .timeSensitive }
    }
    private var withNanoDos: [ToDo] {
        activeToDos.filter { !$0.nanoDos.isEmpty }
    }
    private var withTags: [ToDo] {
        activeToDos.filter { !$0.tags.isEmpty }
    }
    private var completionRate: Int {
        let visible = toDos.filter { $0.lifecycleState != .trashed }.count
        guard visible > 0 else { return 0 }
        return Int((Double(doneToDos.count) / Double(visible) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ToDoMacSurfaceHeader(title: "Stats", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ToDoMacMetric(title: "Active", value: activeToDos.count, color: ToDoMacPalette.brandBlue, icon: "bolt.fill")
                    ToDoMacMetric(title: "Due soon", value: dueSoon.count, color: ToDoMacPalette.brandYellow, icon: "clock.fill")
                    ToDoMacMetric(title: "Overdue", value: overdue.count, color: ToDoMacPalette.urgent, icon: "exclamationmark.circle.fill")
                    ToDoMacMetric(title: "Time-sensitive", value: timeSensitive.count, color: ToDoMacPalette.urgent, icon: "flame.fill")
                    ToDoMacMetric(title: "With NanoDos", value: withNanoDos.count, color: ToDoMacPalette.done, icon: "checklist")
                    ToDoMacMetric(title: "Tagged", value: withTags.count, color: ToDoMacPalette.brandBlue, icon: "tag.fill")
                }

                ToDoMacStatsInsightCard(
                    title: "Momentum",
                    value: "\(AppLocalization.numberString(completionRate))%",
                    detail: completionRate == 0 ? "Start completing toDōs to build a clearer trend." : "Completion rate across visible toDōs.",
                    icon: "speedometer",
                    color: ToDoMacPalette.done
                )

                HStack(spacing: 14) {
                    ToDoMacStatsInsightCard(
                        title: "Workload Shape",
                        value: AppLocalization.numberString(activeToDos.count),
                        detail: "Active toDōs currently asking for attention.",
                        icon: "square.stack.3d.up.fill",
                        color: ToDoMacPalette.brandBlue
                    )
                    ToDoMacStatsInsightCard(
                        title: "Pressure",
                        value: AppLocalization.numberString(overdue.count + timeSensitive.count),
                        detail: "Overdue and time-sensitive items combined.",
                        icon: "flame.fill",
                        color: ToDoMacPalette.urgent,
                        detailLineLimit: 1
                    )
                }
            }
                .padding(.bottom, 10)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ToDoMacSurfaceHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 28, weight: .heavy))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.brandYellow, foreground: ToDoMacPalette.actionForeground(for: colorScheme)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.todoMacDisplay(42))
                    .foregroundStyle(ToDoMacPalette.ink)
            }

            Spacer()
        }
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
        HStack(alignment: .top, spacing: 16) {
            ToDoMacIconBadge(systemName: icon, color: color, size: 18, dimension: 46)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.todoMacDisplay(28))
                    .tracking(0.7)
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                Text(value)
                    .font(.todoMacEntry(36, weight: .medium))
                    .foregroundStyle(color)
                Text(detail)
                    .font(.todoMacUI(14))
                    .foregroundStyle(ToDoMacPalette.mutedInk)
                    .lineLimit(detailLineLimit)
                    .minimumScaleFactor(detailLineLimit == nil ? 1 : 0.88)
                    .allowsTightening(detailLineLimit != nil)
            }
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                    .font(.system(size: 13, weight: .heavy))
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
    let toDo: ToDo
    let isSelected: Bool
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onTrash: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
                }

                Spacer()

                Button(action: onComplete) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .heavy))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.done, foreground: .black))

                Button(action: onTrash) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 15, weight: .heavy))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
            }
            .padding(16)
            .background(isSelected ? ToDoMacPalette.raised : ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ToDoMacCompactRow: View {
    let toDo: ToDo
    let onComplete: () -> Void
    let onTrash: () -> Void

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
                    .font(.todoMacUI(15, weight: .bold))
                    .foregroundStyle(ToDoMacPalette.ink)
                    .lineLimit(1)
                if let dueDate = toDo.dueDate {
                    Text(AppLocalization.dateTimeString(dueDate))
                        .font(.todoMacUI(11))
                        .foregroundStyle(ToDoMacPalette.mutedInk)
                }
            }

            Spacer()

            Button(action: onComplete) {
                Image(systemName: "checkmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.done, foreground: .black))

            Button(action: onTrash) {
                Image(systemName: "trash.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(ToDoMacIconButtonStyle(color: ToDoMacPalette.urgent, foreground: .black))
        }
        .padding(12)
        .background(ToDoMacPalette.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reminderColor: Color {
        toDo.reminderIntent == .timeSensitive ? ToDoMacPalette.urgent : ToDoMacPalette.brandYellow
    }
}

private struct ToDoMacMetric: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ToDoMacIconBadge(systemName: icon, color: color, size: 12, dimension: 24)
                Text(AppLocalization.numberString(value))
                    .font(.todoMacDisplay(28))
                    .foregroundStyle(ToDoMacPalette.ink)
            }
            Text(title)
                .font(.todoMacUI(11, weight: .bold))
                .foregroundStyle(ToDoMacPalette.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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

private struct ToDoMacPrimaryButtonStyle: ButtonStyle {
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ToDoMacIconButtonStyle: ButtonStyle {
    let color: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
