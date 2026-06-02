import Foundation
import SwiftData
import WidgetKit

struct ToDoWidgetSharedConstants {
   static let appGroupIdentifier = SharedStoreLocation.appGroupIdentifier
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
}

struct ToDoWidgetCategorySummary: Codable, Identifiable, Sendable, Hashable {
   let id: String
   let name: String
   let incompleteCount: Int
}

struct ToDoWidgetItem: Codable, Identifiable, Sendable {
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

@MainActor
final class WidgetSnapshotService {
   static let shared = WidgetSnapshotService()

   private let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return encoder
   }()

   private let decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
   }()

   private init() {}

   func processPendingCompletionRequests(in context: ModelContext) {
      do {
         let requests = try loadPendingCompletionRequests()
         guard !requests.isEmpty else { return }

         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         var handledRequestIDs = Set<UUID>()
         var didChange = false

         for request in requests {
            guard let toDo = toDos.first(where: { candidate in
               if String(describing: candidate.id) == request.toDoID {
                  return true
               }
               guard let requestCloudID = request.cloudID else {
                  return false
               }
               return candidate.cloudID == requestCloudID
            }) else { continue }

            guard toDo.lifecycleState == .active else {
               handledRequestIDs.insert(request.id)
               continue
            }

            toDo.transition(to: .done)
            LiveActivityService.shared.endActivity(for: toDo)
            handledRequestIDs.insert(request.id)
            didChange = true
         }

         if didChange {
            try context.save()
            NotificationManager.shared.scheduleRefresh()
            LiveActivityService.shared.refresh(from: context)
            SyncCoordinator.shared.scheduleLocalSync()
         }

         if !handledRequestIDs.isEmpty {
            try savePendingCompletionRequests(requests.filter { !handledRequestIDs.contains($0.id) })
         }
      } catch {
         AppLog.error("Failed to process widget completion requests: \(error)", logger: AppLog.widget)
      }
   }

   func writeSnapshot(from context: ModelContext) {
      do {
         processPendingCompletionRequests(in: context)
         let snapshot = try makeSnapshot(from: context)
         try write(snapshot)
         WidgetCenter.shared.reloadTimelines(ofKind: ToDoWidgetSharedConstants.widgetKind)
      } catch {
         AppLog.error("Failed to write toDō widget snapshot: \(error)", logger: AppLog.widget)
      }
   }

   func writeSnapshot(from container: ModelContainer) {
      let context = ModelContext(container)
      writeSnapshot(from: context)
   }

   private func makeSnapshot(from context: ModelContext) throws -> ToDoWidgetSnapshot {
      let toDos = try context.fetch(FetchDescriptor<ToDo>())
      let now = Date()
      let calendar = Calendar.current
      let syncMode = SyncCoordinator.shared.effectiveSyncMode
      let ownerUserID = syncMode == .syncEverywhere ? SupabaseAuthStore.shared.scopedOwnerUserID : nil
      let focusFilterMode = UserDefaults.standard.string(forKey: AppPreferences.Keys.toDoFocusFilterMode) ?? "all"
      let scopedToDos = toDos.filter { $0.ownerUserID == ownerUserID }
      let activeToDos = scopedToDos.filter { $0.lifecycleState == .active && $0.matchesFocusFilter(modeRawValue: focusFilterMode) }
      let doneToDos = scopedToDos.filter { $0.lifecycleState == .done }
      let sortedActiveToDos = activeToDos.sorted { urgencySort($0, $1, now: now, calendar: calendar) }

      let items = sortedActiveToDos.map { toDo in
         let isOverdue = toDo.dueDate.map { $0 < now } ?? false
         let isDueToday = toDo.dueDate.map { calendar.isDateInToday($0) } ?? false
         return ToDoWidgetItem(
            id: String(describing: toDo.id),
            cloudID: toDo.cloudID,
            missive: toDo.task.isEmpty ? "Untitled toDō" : toDo.task,
            due: toDo.dueDate,
            isDone: toDo.isDoneState,
            isOverdue: isOverdue,
            isDueToday: isDueToday,
            isTimeSensitive: toDo.reminderIntent == .timeSensitive,
            tagNames: Array(toDo.tags.map(\.name).prefix(4))
         )
      }

      return ToDoWidgetSnapshot(
         generatedAt: now,
         syncModeRaw: syncMode.rawValue,
         ownerUserID: ownerUserID,
         activeCount: activeToDos.count,
         doneCount: doneToDos.count,
         overdueCount: activeToDos.filter { $0.dueDate.map { $0 < now } ?? false }.count,
         dueTodayCount: activeToDos.filter { $0.dueDate.map { calendar.isDateInToday($0) } ?? false }.count,
         timeSensitiveCount: activeToDos.filter { $0.reminderIntent == .timeSensitive }.count,
         categories: categorySummaries(from: activeToDos),
         items: items
      )
   }

   private func urgencySort(_ lhs: ToDo, _ rhs: ToDo, now: Date, calendar: Calendar) -> Bool {
      let lhsRank = urgencyRank(for: lhs, now: now, calendar: calendar)
      let rhsRank = urgencyRank(for: rhs, now: now, calendar: calendar)
      if lhsRank != rhsRank { return lhsRank < rhsRank }

      switch (lhs.dueDate, rhs.dueDate) {
      case let (left?, right?):
         if left != right { return left < right }
      case (_?, nil):
         return true
      case (nil, _?):
         return false
      case (nil, nil):
         break
      }

      return lhs.syncUpdatedAt > rhs.syncUpdatedAt
   }

   private func urgencyRank(for toDo: ToDo, now: Date, calendar: Calendar) -> Int {
      guard let dueDate = toDo.dueDate else { return 3 }
      if dueDate < now { return 0 }
      if calendar.isDateInToday(dueDate) { return 1 }
      return 2
   }

   private func categorySummaries(from activeToDos: [ToDo]) -> [ToDoWidgetCategorySummary] {
      let allCategory = ToDoWidgetCategorySummary(id: "__all__", name: "All", incompleteCount: activeToDos.count)
      let counts = activeToDos.reduce(into: [String: Int]()) { partialResult, toDo in
         for tag in toDo.tags {
            partialResult[tag.displayName, default: 0] += 1
         }
      }
      let tagCategories = counts
         .map { ToDoWidgetCategorySummary(id: $0.key, name: $0.key, incompleteCount: $0.value) }
         .sorted { lhs, rhs in
            if lhs.incompleteCount != rhs.incompleteCount { return lhs.incompleteCount > rhs.incompleteCount }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
         }
      return [allCategory] + tagCategories
   }

   private func write(_ snapshot: ToDoWidgetSnapshot) throws {
      let fileURL = try appGroupFileURL(filename: ToDoWidgetSharedConstants.snapshotFilename)
      let data = try encoder.encode(snapshot)
      try data.write(to: fileURL, options: [.atomic])
   }

   private func loadPendingCompletionRequests() throws -> [ToDoWidgetCompletionRequest] {
      let fileURL = try appGroupFileURL(filename: ToDoWidgetSharedConstants.completionQueueFilename)
      guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
      let data = try Data(contentsOf: fileURL)
      return try decoder.decode([ToDoWidgetCompletionRequest].self, from: data)
   }

   private func savePendingCompletionRequests(_ requests: [ToDoWidgetCompletionRequest]) throws {
      let fileURL = try appGroupFileURL(filename: ToDoWidgetSharedConstants.completionQueueFilename)
      let data = try encoder.encode(requests)
      try data.write(to: fileURL, options: [.atomic])
   }

   private func appGroupFileURL(filename: String) throws -> URL {
      guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ToDoWidgetSharedConstants.appGroupIdentifier) else {
         throw WidgetSnapshotError.missingAppGroup
      }
      return containerURL.appendingPathComponent(filename)
   }
}

private enum WidgetSnapshotError: LocalizedError {
   case missingAppGroup

   var errorDescription: String? {
      switch self {
      case .missingAppGroup:
         return "App Group container is unavailable."
      }
   }
}
