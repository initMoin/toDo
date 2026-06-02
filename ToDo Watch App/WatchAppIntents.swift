import AppIntents
import Foundation

struct CreateWatchToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Create toDō"
   static let description = IntentDescription("Create a toDō quickly.")
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
         throw $title.needsValueError("What should this toDō be called?")
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
   static let title: LocalizedStringResource = "toDō"
   static let description = IntentDescription("Create a toDō quickly.")
   static let openAppWhenRun = false

   @Parameter(title: "Title")
   var title: String

   @Parameter(title: "Due Soon")
   var isDueSoon: Bool

   static var parameterSummary: some ParameterSummary {
      Summary("toDō \(\.$title)") {
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
         throw $title.needsValueError("What do you want to toDō?")
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
   static let title: LocalizedStringResource = "Open toDō"
   static let description = IntentDescription("Open toDō.")
   static let openAppWhenRun = true

   func perform() async throws -> some IntentResult & ProvidesDialog {
      .result(dialog: "Opening toDō.")
   }
}

struct WatchToDoShortcutsProvider: AppShortcutsProvider {
   static var appShortcuts: [AppShortcut] {
      AppShortcut(
         intent: WatchToDoIntent(),
         phrases: [
            "Create a toDō in \(.applicationName)",
            "Add a toDō in \(.applicationName)",
            "New toDō in \(.applicationName)"
         ],
         shortTitle: "toDō",
         systemImageName: "bolt.circle"
      )

      AppShortcut(
         intent: CreateWatchToDoIntent(),
         phrases: [
            "Create toDō in \(.applicationName)",
            "Add toDō in \(.applicationName)",
            "Remind me with \(.applicationName)"
         ],
         shortTitle: "Create toDō",
         systemImageName: "checkmark.circle"
      )

      AppShortcut(
         intent: OpenWatchToDoIntent(),
         phrases: [
            "Open \(.applicationName)",
            "Show my toDōs in \(.applicationName)"
         ],
         shortTitle: "Open toDō",
         systemImageName: "list.bullet"
      )
   }
}
