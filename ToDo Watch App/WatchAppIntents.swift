import AppIntents
import Foundation

struct CreateWatchToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Create toDo"
   static let description = IntentDescription("Create a toDo quickly.")
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

   func perform() async throws -> some IntentResult & ProvidesDialog {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTitle.isEmpty else {
         throw $title.needsValueError("What should this toDo be called?")
      }

      await MainActor.run {
         let action = WatchToDoAction(
            type: .create,
            task: trimmedTitle,
            dueDate: dueDate,
            isTimeSensitive: isTimeSensitive
         )
         WatchActionQueueStore().enqueue(action)
      }

      return .result(dialog: "Created \(trimmedTitle).")
   }
}

struct WatchToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "toDo"
   static let description = IntentDescription("Create a toDo quickly.")
   static let openAppWhenRun = false

   @Parameter(title: "Title")
   var title: String

   @Parameter(title: "Due Soon")
   var isDueSoon: Bool

   static var parameterSummary: some ParameterSummary {
      Summary("toDo \(\.$title)") {
         \.$isDueSoon
      }
   }

   init() {
      title = ""
      isDueSoon = false
   }

   init(title: String, isDueSoon: Bool = false) {
      self.title = title
      self.isDueSoon = isDueSoon
   }

   func perform() async throws -> some IntentResult & ProvidesDialog {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTitle.isEmpty else {
         throw $title.needsValueError("What do you want to toDo?")
      }

      let dueDate = isDueSoon ? Date().addingTimeInterval(15 * 60) : nil

      await MainActor.run {
         let action = WatchToDoAction(
            type: .create,
            task: trimmedTitle,
            dueDate: dueDate,
            isTimeSensitive: true
         )
         WatchActionQueueStore().enqueue(action)
      }

      return .result(dialog: "Added \(trimmedTitle).")
   }
}

struct OpenWatchToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Open toDo"
   static let description = IntentDescription("Open toDo.")
   static let openAppWhenRun = true

   func perform() async throws -> some IntentResult & ProvidesDialog {
      .result(dialog: "Opening toDo.")
   }
}

struct WatchToDoShortcutsProvider: AppShortcutsProvider {
   static var appShortcuts: [AppShortcut] {
      AppShortcut(
         intent: WatchToDoIntent(),
         phrases: [
            "Create a toDo in \(.applicationName)",
            "Add a toDo in \(.applicationName)",
            "New toDo in \(.applicationName)"
         ],
         shortTitle: "toDo",
         systemImageName: "bolt.circle"
      )

      AppShortcut(
         intent: CreateWatchToDoIntent(),
         phrases: [
            "Create toDo in \(.applicationName)",
            "Add toDo in \(.applicationName)",
            "Remind me with \(.applicationName)"
         ],
         shortTitle: "Create toDo",
         systemImageName: "checkmark.circle"
      )

      AppShortcut(
         intent: OpenWatchToDoIntent(),
         phrases: [
            "Open \(.applicationName)",
            "Show my toDos in \(.applicationName)"
         ],
         shortTitle: "Open toDo",
         systemImageName: "list.bullet"
      )
   }
}
