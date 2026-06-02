import SwiftUI
import SwiftData
import Auth

struct NanoDoEditorView: View {
    enum Mode {
        case create(toDo: ToDo)
        case edit(nanoDo: NanoDo)

        var navigationTitle: String {
            switch self {
            case .create:
                return "New nanoDo"
            case .edit:
                return "Edit nanoDo"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabaseAuthStore: SupabaseAuthStore

    private let mode: Mode

    @State private var task: String
    @State private var isDone: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _task = State(initialValue: "")
            _isDone = State(initialValue: false)
            _hasDueDate = State(initialValue: false)
            _dueDate = State(initialValue: Date())
        case .edit(let nanoDo):
            _task = State(initialValue: nanoDo.task)
            _isDone = State(initialValue: nanoDo.isDone)
            if let dueDate = nanoDo.dueDate {
                _hasDueDate = State(initialValue: true)
                _dueDate = State(initialValue: dueDate)
            } else {
                _hasDueDate = State(initialValue: false)
                _dueDate = State(initialValue: Date())
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                AppLargeScreenTitle(title: mode.navigationTitle)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Section("Task") {
                    TextField("Task", text: $task)
                    Toggle("Completed", isOn: $isDone)
                }
                .listRowBackground(AppColor.surfaceElevated)

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
                .listRowBackground(AppColor.surfaceElevated)
            }
            .appListChrome()
            .tint(AppColor.actionPrimary)
            .appBaseTypography()
            .appNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var visibleOwnerUserID: UUID? {
        guard supabaseAuthStore.effectiveSyncMode == .syncEverywhere else { return nil }
        return supabaseAuthStore.scopedOwnerUserID
    }

    private func save() {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else { return }

        let resolvedDueDate = hasDueDate ? dueDate : nil
        switch mode {
        case .create(let toDo):
            let nanoDo = NanoDo(
                task: trimmedTask,
                dueDate: resolvedDueDate,
                isDone: isDone,
                toDo: toDo,
                tag: toDo.effectiveTags.first,
                ownerUserID: visibleOwnerUserID
            )
            toDo.nanoDos.append(nanoDo)
            context.insert(nanoDo)
        case .edit(let nanoDo):
            nanoDo.task = trimmedTask
            nanoDo.dueDate = resolvedDueDate
            nanoDo.isDone = isDone
            nanoDo.markUpdated()
        }

        do {
            try context.save()
            NotificationManager.shared.scheduleRefresh()
            SyncCoordinator.shared.scheduleLocalSync()
        } catch {
            AppLog.error("Failed to save nanoDo: \(error)", logger: AppLog.app)
            return
        }

        dismiss()
    }
}

#Preview {
    let container = PreviewSupport.makeModelContainer()
    let toDo = ToDo(task: "Parent")
    container.mainContext.insert(toDo)
    return NanoDoEditorView(mode: .create(toDo: toDo))
        .modelContainer(container)
        .environmentObject(SupabaseAuthStore.preview)
}
