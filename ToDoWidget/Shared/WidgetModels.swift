import Foundation

struct ToDoWidgetSharedConstants {
   static let appGroupIdentifier = "group.dev.iamshift.toDo"
   static let snapshotFilename = "todo-widget-snapshot.json"
   static let completionQueueFilename = "todo-widget-completion-queue.json"
   static let widgetKind = "ToDoWidget"
}

struct ToDoWidgetSnapshot: Codable, Sendable {
   let generatedAt: Date
   let syncModeRaw: String
   let ownerUserID: UUID?
   let activeCount: Int
   let doneCount: Int
   let overdueCount: Int
   let dueTodayCount: Int
   let timeSensitiveCount: Int
   let categories: [ToDoWidgetCategorySummary]
   let items: [ToDoWidgetItem]

   static let empty = ToDoWidgetSnapshot(
      generatedAt: .now,
      syncModeRaw: SyncMode.deviceOnly.rawValue,
      ownerUserID: nil,
      activeCount: 0,
      doneCount: 0,
      overdueCount: 0,
      dueTodayCount: 0,
      timeSensitiveCount: 0,
      categories: [ToDoWidgetCategorySummary(id: "__all__", name: "All", incompleteCount: 0)],
      items: []
   )

   static let placeholder = ToDoWidgetSnapshot(
      generatedAt: .now,
      syncModeRaw: SyncMode.deviceOnly.rawValue,
      ownerUserID: nil,
      activeCount: 4,
      doneCount: 8,
      overdueCount: 1,
      dueTodayCount: 2,
      timeSensitiveCount: 1,
      categories: [
         ToDoWidgetCategorySummary(id: "__all__", name: "All", incompleteCount: 4),
         ToDoWidgetCategorySummary(id: "work", name: "work", incompleteCount: 3)
      ],
      items: [
         ToDoWidgetItem(id: "preview-1", cloudID: nil, missive: "Review launch checklist", due: .now.addingTimeInterval(-900), isDone: false, isOverdue: true, isDueToday: true, isTimeSensitive: true, tagNames: ["release", "ios", "qa"]),
         ToDoWidgetItem(id: "preview-2", cloudID: nil, missive: "Send build notes", due: .now.addingTimeInterval(3600), isDone: false, isOverdue: false, isDueToday: true, isTimeSensitive: false, tagNames: ["swiftdata"]),
         ToDoWidgetItem(id: "preview-3", cloudID: nil, missive: "Prepare demo outline", due: .now.addingTimeInterval(86_400), isDone: false, isOverdue: false, isDueToday: false, isTimeSensitive: false, tagNames: ["planning", "team"]),
         ToDoWidgetItem(id: "preview-4", cloudID: nil, missive: "Clean up notes", due: nil, isDone: false, isOverdue: false, isDueToday: false, isTimeSensitive: false, tagNames: [])
      ]
   )
}

struct ToDoWidgetCategorySummary: Codable, Identifiable, Sendable, Hashable {
   let id: String
   let name: String
   let incompleteCount: Int
}

struct ToDoWidgetItem: Codable, Identifiable, Sendable, Hashable {
   let id: String
   let cloudID: UUID?
   let missive: String
   let due: Date?
   let isDone: Bool
   let isOverdue: Bool
   let isDueToday: Bool
   let isTimeSensitive: Bool
   let tagNames: [String]
}

struct ToDoWidgetCompletionRequest: Codable, Identifiable, Sendable, Hashable {
   let id: UUID
   let toDoID: String
   let cloudID: UUID?
   let completedAt: Date

   init(toDoID: String, cloudID: UUID?, completedAt: Date = .now) {
      id = UUID()
      self.toDoID = toDoID
      self.cloudID = cloudID
      self.completedAt = completedAt
   }
}
