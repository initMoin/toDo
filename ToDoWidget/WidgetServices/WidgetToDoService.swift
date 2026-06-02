import Foundation
import SwiftData
import WidgetKit

struct WidgetToDoService {
   private static var cachedModelContainer: ModelContainer?
   private static var cachedSyncMode: SyncMode?
   private let fileManager = FileManager.default

   func snapshot() -> ToDoWidgetSnapshot? {
      let persistedSnapshot = persistedSnapshot()
      guard let persistedSnapshot else {
         return nil
      }
      if let freshSnapshot = freshSnapshot(using: persistedSnapshot) {
         return freshSnapshot
      }
      return persistedSnapshot.isStale ? .empty : persistedSnapshot
   }

   private func persistedSnapshot() -> ToDoWidgetSnapshot? {
      guard let fileURL = appGroupFileURL(filename: ToDoWidgetSharedConstants.snapshotFilename),
            let data = try? Data(contentsOf: fileURL) else {
         return nil
      }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try? decoder.decode(ToDoWidgetSnapshot.self, from: data)
   }

   private func freshSnapshot(using persistedSnapshot: ToDoWidgetSnapshot) -> ToDoWidgetSnapshot? {
      do {
         let context = ModelContext(try modelContainer(for: persistedSnapshot))
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         let now = Date()
         let calendar = Calendar.current
         let ownerUserID = persistedSnapshot.ownerUserID
         let focusFilterMode = UserDefaults(suiteName: ToDoWidgetSharedConstants.appGroupIdentifier)?
            .string(forKey: AppPreferences.Keys.toDoFocusFilterMode) ?? "all"
         let scopedToDos = toDos.filter { $0.ownerUserID == ownerUserID }
         let activeToDos = scopedToDos.filter { $0.lifecycleState == .active && $0.matchesFocusFilter(modeRawValue: focusFilterMode) }
         let doneToDos = scopedToDos.filter { $0.lifecycleState == .done }
         let sortedActiveToDos = activeToDos.sorted { lhs, rhs in
            urgencySort(lhs, rhs, now: now, calendar: calendar)
         }

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
            syncModeRaw: persistedSnapshot.syncModeRaw,
            ownerUserID: ownerUserID,
            activeCount: activeToDos.count,
            doneCount: doneToDos.count,
            overdueCount: activeToDos.filter { $0.dueDate.map { $0 < now } ?? false }.count,
            dueTodayCount: activeToDos.filter { $0.dueDate.map { calendar.isDateInToday($0) } ?? false }.count,
            timeSensitiveCount: activeToDos.filter { $0.reminderIntent == .timeSensitive }.count,
            categories: categorySummaries(from: activeToDos),
            items: items
         )
      } catch {
         AppLog.error("Widget could not build fresh snapshot from SwiftData: \(error)", logger: AppLog.widget)
         return nil
      }
   }

   func complete(toDoID: String, cloudID: UUID?) throws {
      let currentSnapshot = snapshot() ?? .empty
      do {
         try markSharedStoreToDoDone(toDoID: toDoID, cloudID: cloudID, snapshot: currentSnapshot)
      } catch {
         AppLog.error("Widget could not write completion directly to SwiftData: \(error)", logger: AppLog.widget)
      }
      let updatedSnapshot = currentSnapshot.removingToDo(id: toDoID, cloudID: cloudID)
      try write(snapshot: updatedSnapshot)
      try enqueueCompletion(toDoID: toDoID, cloudID: cloudID)
      WidgetCenter.shared.reloadTimelines(ofKind: ToDoWidgetSharedConstants.widgetKind)
   }

   private func markSharedStoreToDoDone(toDoID: String, cloudID: UUID?, snapshot: ToDoWidgetSnapshot) throws {
      let context = ModelContext(try modelContainer(for: snapshot))
      let toDos = try context.fetch(FetchDescriptor<ToDo>())

      guard let toDo = toDos.first(where: { candidate in
         guard candidate.ownerUserID == snapshot.ownerUserID else {
            return false
         }
         if String(describing: candidate.id) == toDoID {
            return true
         }
         guard let cloudID else {
            return false
         }
         return candidate.cloudID == cloudID
      }) else {
         return
      }

      guard toDo.lifecycleState == .active else { return }
      toDo.transition(to: .done)
      try context.save()
   }

   private func modelContainer(for snapshot: ToDoWidgetSnapshot) throws -> ModelContainer {
      let syncMode = SyncMode(rawValue: snapshot.syncModeRaw) ?? AppPreferences.preferredSyncMode()
      if let cachedModelContainer = Self.cachedModelContainer,
         Self.cachedSyncMode == syncMode {
         return cachedModelContainer
      }

      SharedStoreLocation.migrateLegacyStoresIfNeeded()
      let storeURL = SharedStoreLocation.storeURL(for: syncMode)
      SharedStoreLocation.ensureStoreDirectoryExists(for: storeURL)

      let configuration = ModelConfiguration(
         "toDō",
         url: storeURL,
         cloudKitDatabase: CloudKitConfig.database(for: syncMode)
      )
      let container = try ModelContainer(
         for: ToDo.self,
         Tag.self,
         NanoDo.self,
         SyncConflict.self,
         configurations: configuration
      )
      Self.cachedModelContainer = container
      Self.cachedSyncMode = syncMode
      return container
   }

   private func write(snapshot: ToDoWidgetSnapshot) throws {
      guard let fileURL = appGroupFileURL(filename: ToDoWidgetSharedConstants.snapshotFilename) else { return }
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(snapshot)
      try data.write(to: fileURL, options: [.atomic])
   }

   private func enqueueCompletion(toDoID: String, cloudID: UUID?) throws {
      guard let fileURL = appGroupFileURL(filename: ToDoWidgetSharedConstants.completionQueueFilename) else { return }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let existing: [ToDoWidgetCompletionRequest]
      if let data = try? Data(contentsOf: fileURL) {
         existing = (try? decoder.decode([ToDoWidgetCompletionRequest].self, from: data)) ?? []
      } else {
         existing = []
      }

      var requests = existing
      requests.append(ToDoWidgetCompletionRequest(toDoID: toDoID, cloudID: cloudID))
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(requests)
      try data.write(to: fileURL, options: [.atomic])
   }

   private func appGroupFileURL(filename: String) -> URL? {
      fileManager
         .containerURL(forSecurityApplicationGroupIdentifier: ToDoWidgetSharedConstants.appGroupIdentifier)?
         .appendingPathComponent(filename)
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
}

private extension ToDoWidgetSnapshot {
   var isStale: Bool {
      generatedAt < Date().addingTimeInterval(-12 * 60 * 60)
   }

   func removingToDo(id: String, cloudID: UUID?) -> ToDoWidgetSnapshot {
      let updatedItems = items.filter { item in
         guard item.id != id else {
            return false
         }
         guard let cloudID else {
            return true
         }
         return item.cloudID != cloudID
      }
      let removedCount = items.count - updatedItems.count
      guard removedCount > 0 else { return self }
      let categories = categories.map { category in
         let incompleteCount = category.name == "All"
            ? updatedItems.count
            : updatedItems.filter { $0.tagNames.contains(category.name) }.count
         return ToDoWidgetCategorySummary(
            id: category.id,
            name: category.name,
            incompleteCount: incompleteCount
         )
      }
      return ToDoWidgetSnapshot(
         generatedAt: .now,
         syncModeRaw: syncModeRaw,
         ownerUserID: ownerUserID,
         activeCount: max(activeCount - removedCount, 0),
         doneCount: doneCount + removedCount,
         overdueCount: updatedItems.filter(\.isOverdue).count,
         dueTodayCount: updatedItems.filter(\.isDueToday).count,
         timeSensitiveCount: updatedItems.filter(\.isTimeSensitive).count,
         categories: categories,
         items: updatedItems
      )
   }
}
