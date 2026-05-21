import AppIntents
import Foundation
import WidgetKit

struct ToDoCategoryOptionsProvider: DynamicOptionsProvider {
   func results() async throws -> [String] {
      let categories = WidgetToDoService().snapshot()?.categories ?? []
      let names = categories.map(\.name)
      return names.isEmpty ? ["All"] : names
   }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
   static var title: LocalizedStringResource { "ToDo Widget" }
   static var description: IntentDescription { "Choose the category this widget should show." }

   @Parameter(title: "Category", optionsProvider: ToDoCategoryOptionsProvider())
   var category: String?

   init() {
      category = nil
   }
}

struct CompleteWidgetToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Mark ToDo Done"
   static let description = IntentDescription("Mark this ToDo as done from the widget.")
   static let openAppWhenRun = false

   @Parameter(title: "ToDo ID")
   var toDoID: String

   @Parameter(title: "Cloud ID")
   var cloudID: String?

   init() {
      toDoID = ""
      cloudID = nil
   }

   init(toDoID: String, cloudID: UUID?) {
      self.toDoID = toDoID
      self.cloudID = cloudID?.uuidString
   }

   func perform() async throws -> some IntentResult {
      try WidgetToDoService().complete(toDoID: toDoID, cloudID: cloudID.flatMap(UUID.init(uuidString:)))
      return .result()
   }
}
