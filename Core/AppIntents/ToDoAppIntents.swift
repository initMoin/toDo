import AppIntents
import Foundation
import SwiftData

struct ToDoAppEntity: AppEntity, Identifiable {
   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "ToDo")
   static let defaultQuery = ToDoEntityQuery()

   let id: String

   @Property(title: "Title")
   var title: String

   @Property(title: "Due Date")
   var dueDate: Date?

   var displayRepresentation: DisplayRepresentation {
      if let dueDate {
         DisplayRepresentation(
            title: "\(title)",
            subtitle: "Due \(dueDate.formatted(date: .abbreviated, time: .shortened))"
         )
      } else {
         DisplayRepresentation(title: "\(title)")
      }
   }
}

struct ToDoEntityQuery: EntityStringQuery {
   @MainActor
   func entities(for identifiers: [ToDoAppEntity.ID]) async throws -> [ToDoAppEntity] {
      let context = try ToDoIntentStore.modelContext()
      let toDos = try context.fetch(FetchDescriptor<ToDo>())
      let requestedIdentifiers = Set(identifiers)

      return toDos.compactMap { toDo in
         let identifier = ToDoIntentStore.persistentIdentifierString(for: toDo)
         guard requestedIdentifiers.contains(identifier) else { return nil }
         return ToDoAppEntity(from: toDo, id: identifier)
      }
   }

   @MainActor
   func entities(matching string: String) async throws -> [ToDoAppEntity] {
      let searchTerm = string.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
      guard !searchTerm.isEmpty else {
         return try await suggestedEntities()
      }

      let context = try ToDoIntentStore.modelContext()
      let toDos = try context.fetch(activeToDoDescriptor())
      return toDos
         .filter { $0.task.localizedLowercase.contains(searchTerm) }
         .prefix(10)
         .map { ToDoAppEntity(from: $0) }
   }

   @MainActor
   func suggestedEntities() async throws -> [ToDoAppEntity] {
      let context = try ToDoIntentStore.modelContext()
      return try context.fetch(activeToDoDescriptor())
         .prefix(10)
         .map { ToDoAppEntity(from: $0) }
   }

   private func activeToDoDescriptor() -> FetchDescriptor<ToDo> {
      FetchDescriptor<ToDo>(
         predicate: #Predicate { toDo in
            toDo.lifecycleStateRaw == "active"
         },
         sortBy: [
            SortDescriptor(\.dueDate, order: .forward),
            SortDescriptor(\.updatedAt, order: .reverse),
            SortDescriptor(\.createdAt, order: .reverse)
         ]
      )
   }
}

extension ToDoAppEntity {
   @MainActor
   init(from toDo: ToDo, id: String? = nil) {
      self.id = id ?? ToDoIntentStore.persistentIdentifierString(for: toDo)
      title = toDo.task.isEmpty ? "Untitled ToDo" : toDo.task
      dueDate = toDo.dueDate
   }
}

struct CreateToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Create ToDo"
   static let description = IntentDescription("Create a new ToDo quickly.")
   static let openAppWhenRun = false

   @Parameter(title: "Title")
   var title: String

   @Parameter(title: "Due Date")
   var dueDate: Date?

   @Parameter(title: "Time-Sensitive")
   var isTimeSensitive: Bool

   static var parameterSummary: some ParameterSummary {
      Summary("Create \(\.$title)") {
         \.$dueDate
         \.$isTimeSensitive
      }
   }

   init() {
      title = ""
      dueDate = nil
      isTimeSensitive = false
   }

   init(title: String, dueDate: Date? = nil, isTimeSensitive: Bool = false) {
      self.title = title
      self.dueDate = dueDate
      self.isTimeSensitive = isTimeSensitive
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTitle.isEmpty else {
         throw $title.needsValueError("What should this ToDo be called?")
      }

      let context = try ToDoIntentStore.modelContext()
      let toDo = ToDo(
         task: trimmedTitle,
         dueDate: dueDate,
         reminderIntent: dueDate == nil ? .soft : (isTimeSensitive ? .timeSensitive : .due)
      )
      context.insert(toDo)
      try context.save()

      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
      LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
      if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar) {
         try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
         try context.save()
      }
      SyncCoordinator.shared.scheduleLocalSync()

      return .result(dialog: "Created \(trimmedTitle).")
   }
}

struct CompleteToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Complete ToDo"
   static let description = IntentDescription("Mark an active ToDo as done.")
   static let openAppWhenRun = false

   @Parameter(title: "ToDo")
   var toDo: ToDoAppEntity

   static var parameterSummary: some ParameterSummary {
      Summary("Complete \(\.$toDo)")
   }

   init() {}

   init(toDo: ToDoAppEntity) {
      self.toDo = toDo
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      let context = try ToDoIntentStore.modelContext()
      let toDos = try context.fetch(FetchDescriptor<ToDo>())

      guard let target = toDos.first(where: { ToDoIntentStore.persistentIdentifierString(for: $0) == toDo.id }) else {
         return .result(dialog: "That ToDo could not be found.")
      }

      target.transition(to: .done)
      LiveActivityService.shared.endActivity(for: target)
      try context.save()

      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
      LiveActivityService.shared.refresh(from: context)
      if target.calendarEventIdentifier != nil {
         try CalendarIntegrationService.shared.removeCalendarEvent(for: target)
         try context.save()
      }
      SyncCoordinator.shared.scheduleLocalSync()

      return .result(dialog: "Completed \(target.task).")
   }
}

struct CreateTimeSensitiveToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Create Time-Sensitive ToDo"
   static let description = IntentDescription("Create a ToDo that should be treated as time-sensitive.")
   static let openAppWhenRun = false

   @Parameter(title: "Title")
   var title: String

   @Parameter(title: "Due Date")
   var dueDate: Date

   static var parameterSummary: some ParameterSummary {
      Summary("Create time-sensitive \(\.$title)") {
         \.$dueDate
      }
   }

   init() {
      title = ""
      dueDate = .now
   }

   init(title: String, dueDate: Date = .now) {
      self.title = title
      self.dueDate = dueDate
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTitle.isEmpty else {
         throw $title.needsValueError("What should this time-sensitive ToDo be called?")
      }

      let context = try ToDoIntentStore.modelContext()
      let toDo = ToDo(
         task: trimmedTitle,
         dueDate: dueDate,
         reminderIntent: .timeSensitive
      )
      context.insert(toDo)
      try context.save()

      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
      LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
      if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar) {
         try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
         try context.save()
      }
      SyncCoordinator.shared.scheduleLocalSync()

      return .result(dialog: "Created time-sensitive ToDo \(trimmedTitle).")
   }
}

struct OpenToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Open ToDo"
   static let description = IntentDescription("Open ToDo to review your list.")
   static let openAppWhenRun = true

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .all
      return .result(dialog: "Opening ToDo.")
   }
}

struct OpenTodayToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "Show Today’s ToDos"
   static let description = IntentDescription("Open ToDo and show active ToDos due today.")
   static let openAppWhenRun = true

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .today
      return .result(dialog: "Showing today’s ToDos.")
   }
}

struct OpenOverdueToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "Show Overdue ToDos"
   static let description = IntentDescription("Open ToDo and show active overdue ToDos.")
   static let openAppWhenRun = true

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .overdue
      return .result(dialog: "Showing overdue ToDos.")
   }
}

struct OpenDueToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "Show Due ToDos"
   static let description = IntentDescription("Open ToDo and show active ToDos with due dates.")
   static let openAppWhenRun = true

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .due
      return .result(dialog: "Showing due ToDos.")
   }
}

struct OpenTimeSensitiveToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "Show Time-Sensitive ToDos"
   static let description = IntentDescription("Open ToDo and show active time-sensitive ToDos.")
   static let openAppWhenRun = true

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .timeSensitive
      return .result(dialog: "Showing time-sensitive ToDos.")
   }
}

struct SummarizeToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "Summarize ToDos"
   static let description = IntentDescription("Summarize local ToDo patterns and current task pressure.")
   static let openAppWhenRun = false

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
      let context = try ToDoIntentStore.modelContext()
      let toDos = try context.fetch(FetchDescriptor<ToDo>())
      let active = toDos.filter(\.isActive)
      let completed = toDos.filter { $0.lifecycleState == .done }
      let overdue = active.filter(\.isLate)
      let dueToday = active.filter { toDo in
         guard let dueDate = toDo.dueDate else { return false }
         return Calendar.current.isDateInToday(dueDate)
      }
      let timeSensitive = active.filter { $0.reminderIntent == .timeSensitive }
      let staleCutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
      let stale = active.filter { $0.syncUpdatedAt < staleCutoff }
      let completedLastSevenDays = completed.filter { toDo in
         let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
         return toDo.syncUpdatedAt >= cutoff
      }
      let focusPressureScore = min((overdue.count * 4) + (timeSensitive.count * 3) + (dueToday.count * 2) + active.count, 100)

      let summary = [
         String(localized: "ToDo summary:"),
         String(format: String(localized: "%@ active."), AppLocalization.numberString(active.count)),
         String(format: String(localized: "%@ overdue."), AppLocalization.numberString(overdue.count)),
         String(format: String(localized: "%@ due today."), AppLocalization.numberString(dueToday.count)),
         String(format: String(localized: "%@ time-sensitive."), AppLocalization.numberString(timeSensitive.count)),
         String(format: String(localized: "%@ completed in the last 7 days."), AppLocalization.numberString(completedLastSevenDays.count)),
         String(format: String(localized: "%@ stale for more than 14 days."), AppLocalization.numberString(stale.count)),
         String(format: String(localized: "Focus pressure: %@/100."), AppLocalization.numberString(focusPressureScore))
      ].joined(separator: " ")

      return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
   }
}

enum ToDoFocusFilterMode: String, AppEnum {
   case all
   case timeSensitiveOnly
   case dueOnly

   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "ToDo Focus")
   static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .all: "All ToDos",
      .timeSensitiveOnly: "Time-Sensitive Only",
      .dueOnly: "Due ToDos Only"
   ]
}

struct SetToDoFocusFilterIntent: SetFocusFilterIntent {
   static let title: LocalizedStringResource = "Set ToDo Focus Filter"
   static let description = IntentDescription("Choose which ToDo notifications and app surfaces should be active during a Focus.")

   @Parameter(title: "Mode")
   var mode: ToDoFocusFilterMode?

   var displayRepresentation: DisplayRepresentation {
      DisplayRepresentation(title: "\(resolvedMode.displayTitle)")
   }

   var appContext: FocusFilterAppContext {
      switch resolvedMode {
      case .all:
         return FocusFilterAppContext(notificationFilterPredicate: nil, targetContentIdentifierPrefix: "todo")
      case .timeSensitiveOnly:
         return FocusFilterAppContext(notificationFilterPredicate: nil, targetContentIdentifierPrefix: "todo")
      case .dueOnly:
         return FocusFilterAppContext(notificationFilterPredicate: nil, targetContentIdentifierPrefix: "todo")
      }
   }

   init() {
      mode = nil
   }

   init(mode: ToDoFocusFilterMode) {
      self.mode = mode
   }

   static func suggestedFocusFilters(for context: FocusFilterSuggestionContext) async -> [SetToDoFocusFilterIntent] {
      [
         SetToDoFocusFilterIntent(mode: .timeSensitiveOnly),
         SetToDoFocusFilterIntent(mode: .dueOnly),
         SetToDoFocusFilterIntent(mode: .all)
      ]
   }

   @MainActor
   func perform() async throws -> some IntentResult {
      UserDefaults.standard.set(resolvedMode.rawValue, forKey: AppPreferences.Keys.toDoFocusFilterMode)
      UserDefaults(suiteName: SharedStoreLocation.appGroupIdentifier)?
         .set(resolvedMode.rawValue, forKey: AppPreferences.Keys.toDoFocusFilterMode)
      NotificationManager.shared.scheduleRefresh()
      return .result()
   }

   private var resolvedMode: ToDoFocusFilterMode {
      mode ?? .timeSensitiveOnly
   }
}

private extension ToDoFocusFilterMode {
   var displayTitle: String {
      switch self {
      case .all:
         return "All ToDos"
      case .timeSensitiveOnly:
         return "Time-Sensitive Only"
      case .dueOnly:
         return "Due ToDos Only"
      }
   }
}

struct ToDoShortcutsProvider: AppShortcutsProvider {
   static var appShortcuts: [AppShortcut] {
      AppShortcut(
         intent: CreateToDoIntent(),
         phrases: [
            "Create a ToDo in \(.applicationName)",
            "Add a ToDo in \(.applicationName)",
            "Remind me with \(.applicationName)"
         ],
         shortTitle: "Create ToDo",
         systemImageName: "checkmark.circle"
      )

      AppShortcut(
         intent: CreateTimeSensitiveToDoIntent(),
         phrases: [
            "Create a time-sensitive ToDo in \(.applicationName)",
            "Add a time-sensitive ToDo in \(.applicationName)",
            "Create an urgent ToDo in \(.applicationName)"
         ],
         shortTitle: "Urgent ToDo",
         systemImageName: "exclamationmark.circle"
      )

      AppShortcut(
         intent: CompleteToDoIntent(),
         phrases: [
            "Complete a ToDo in \(.applicationName)",
            "Mark a ToDo done in \(.applicationName)"
         ],
         shortTitle: "Complete ToDo",
         systemImageName: "checkmark.circle.fill"
      )

      AppShortcut(
         intent: OpenToDoIntent(),
         phrases: [
            "Open \(.applicationName)",
            "Show my ToDos in \(.applicationName)"
         ],
         shortTitle: "Open ToDo",
         systemImageName: "list.bullet"
      )

      AppShortcut(
         intent: OpenTodayToDosIntent(),
         phrases: [
            "Show today's ToDos in \(.applicationName)",
            "Open today's ToDos in \(.applicationName)"
         ],
         shortTitle: "Today",
         systemImageName: "calendar"
      )

      AppShortcut(
         intent: OpenOverdueToDosIntent(),
         phrases: [
            "Show overdue ToDos in \(.applicationName)",
            "Open overdue ToDos in \(.applicationName)"
         ],
         shortTitle: "Overdue",
         systemImageName: "exclamationmark.circle"
      )

      AppShortcut(
         intent: OpenDueToDosIntent(),
         phrases: [
            "Show due ToDos in \(.applicationName)",
            "Open due ToDos in \(.applicationName)"
         ],
         shortTitle: "Due",
         systemImageName: "bell"
      )

      AppShortcut(
         intent: OpenTimeSensitiveToDosIntent(),
         phrases: [
            "Show time-sensitive ToDos in \(.applicationName)",
            "Open time-sensitive ToDos in \(.applicationName)",
            "Show urgent ToDos in \(.applicationName)"
         ],
         shortTitle: "Time-Sensitive",
         systemImageName: "clock.badge.exclamationmark"
      )

      AppShortcut(
         intent: SummarizeToDosIntent(),
         phrases: [
            "Summarize my ToDos in \(.applicationName)",
            "Show my ToDo summary in \(.applicationName)",
            "Check my ToDo stats in \(.applicationName)"
         ],
         shortTitle: "Summarize",
         systemImageName: "chart.bar.doc.horizontal"
      )
   }
}
