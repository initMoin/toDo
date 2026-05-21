import ActivityKit
import Foundation

struct ToDoLiveActivityAttributes: ActivityAttributes {
   struct ContentState: Codable, Hashable {
      var title: String
      var dueDate: Date?
      var isOverdue: Bool
      var isTimeSensitive: Bool
      var updatedAt: Date
   }

   var toDoIdentifier: String
   var toDoLocalIdentifier: String?
   var toDoCloudIdentifier: String?
   var createdAt: Date
}
