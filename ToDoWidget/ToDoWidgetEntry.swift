import Foundation
import WidgetKit

struct ToDoWidgetEntry: TimelineEntry {
   let date: Date
   let configuration: ConfigurationAppIntent
   let snapshot: ToDoWidgetSnapshot

   var selectedCategory: String {
      let rawValue = configuration.category?.trimmingCharacters(in: .whitespacesAndNewlines)
      return rawValue?.isEmpty == false ? rawValue! : "All"
   }

   var filteredItems: [ToDoWidgetItem] {
      let activeItems = snapshot.items.filter { !$0.isDone }
      guard selectedCategory != "All" else { return activeItems }
      return activeItems.filter { $0.tagNames.contains(selectedCategory) }
   }

   var filteredCount: Int {
      filteredItems.count
   }
}
