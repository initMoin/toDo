import ActivityKit
import Foundation

nonisolated struct ToDoLiveActivityAttributes: ActivityAttributes, Sendable {
   nonisolated struct ContentState: Codable, Hashable, Sendable {
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
