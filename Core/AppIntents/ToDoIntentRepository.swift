import Foundation
import SwiftData

struct ToDoIntentSnapshot: Sendable {
   let identifier: String
   let title: String
   let dueDate: Date?
}

struct ToDoIntentLocation: Sendable {
   let latitude: Double
   let longitude: Double
   let label: String
   let trigger: ToDoLocationReminderTrigger
}

@MainActor
final class ToDoIntentRepository: @unchecked Sendable {
   private let modelContainer: ModelContainer
   private let performsMutationSideEffects: Bool
   private let accessibleCollabIDsProvider: @MainActor () -> Set<UUID>

   init(
      modelContainer: ModelContainer,
      performsMutationSideEffects: Bool = true,
      accessibleCollabIDsProvider: @escaping @MainActor () -> Set<UUID> = {
         Set(ToDoCollaborationService.shared.collabs.map(\.id))
      }
   ) {
      self.modelContainer = modelContainer
      self.performsMutationSideEffects = performsMutationSideEffects
      self.accessibleCollabIDsProvider = accessibleCollabIDsProvider
   }

   func activeToDos(matching searchText: String? = nil, limit: Int = 10) throws -> [ToDoIntentSnapshot] {
      let context = ModelContext(modelContainer)
      let descriptor = FetchDescriptor<ToDo>(
         predicate: #Predicate { toDo in
            toDo.lifecycleStateRaw == "active"
         },
         sortBy: [
            SortDescriptor(\ToDo.dueDate, order: .forward),
            SortDescriptor(\ToDo.updatedAt, order: .reverse),
            SortDescriptor(\ToDo.createdAt, order: .reverse)
         ]
      )
      let normalizedSearchText = searchText?
         .trimmingCharacters(in: .whitespacesAndNewlines)
         .localizedLowercase

      return try context.fetch(descriptor)
         .lazy
         .filter(isVisibleInCurrentScope(_:))
         .filter { toDo in
            guard let normalizedSearchText, !normalizedSearchText.isEmpty else { return true }
            return toDo.task.localizedLowercase.contains(normalizedSearchText)
         }
         .prefix(limit)
         .map(snapshot(for:))
   }

   func allToDos(matching searchText: String? = nil, limit: Int = 25) throws -> [ToDoIntentSnapshot] {
      let context = ModelContext(modelContainer)
      let normalizedSearchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
      return try context.fetch(FetchDescriptor<ToDo>())
         .lazy
         .filter(isVisibleInCurrentScope(_:))
         .filter { toDo in
            guard let normalizedSearchText, !normalizedSearchText.isEmpty else { return true }
            return toDo.task.localizedLowercase.contains(normalizedSearchText)
         }
         .sorted { ToDo.presentationDueDateSort($0, $1) }
         .prefix(limit)
         .map(snapshot(for:))
   }

   func toDos(identifiedBy identifiers: Set<String>) throws -> [ToDoIntentSnapshot] {
      guard !identifiers.isEmpty else { return [] }

      let context = ModelContext(modelContainer)
      return try context.fetch(FetchDescriptor<ToDo>())
         .filter(isVisibleInCurrentScope(_:))
         .filter { identifiers.contains(identifier(for: $0)) }
         .map(snapshot(for:))
   }

   func create(
      title: String,
      dueDate: Date?,
      isTimeSensitive: Bool,
      notes: String = "",
      reminderIntent: ToDoReminderIntent? = nil,
      tagNames: [String] = [],
      nanoDoTitles: [String] = [],
      recurrenceUnit: ToDoRecurrenceUnit? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceMode: ToDoRecurrenceMode? = nil,
      recurrenceCount: Int? = nil,
      recurrenceEndDate: Date? = nil,
      location: ToDoIntentLocation? = nil
   ) async throws -> ToDoIntentSnapshot {
      let context = ModelContext(modelContainer)
      let ownerUserID = visibleOwnerUserID
      let selectedTags = try resolveTags(
         named: tagNames,
         ownerUserID: ownerUserID,
         context: context
      )
      let resolvedReminder = dueDate == nil
         ? ToDoReminderIntent.soft
         : (reminderIntent ?? (isTimeSensitive ? .timeSensitive : .due))
      let resolvedRecurrenceUnit = dueDate == nil ? nil : recurrenceUnit
      let resolvedRecurrenceInterval = resolvedRecurrenceUnit == nil
         ? nil
         : max(recurrenceInterval ?? 1, 1)
      let resolvedRecurrenceMode = resolvedRecurrenceUnit == nil
         ? nil
         : (recurrenceMode ?? .continuous)
      let toDo = ToDo(
         task: title,
         notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
         dueDate: dueDate,
         reminderIntent: resolvedReminder,
         recurrenceUnit: resolvedRecurrenceUnit,
         recurrenceInterval: resolvedRecurrenceInterval,
         recurrenceMode: resolvedRecurrenceMode,
         recurrenceCount: resolvedRecurrenceMode == .finite ? recurrenceCount : nil,
         recurrenceAnchorDate: resolvedRecurrenceUnit == nil ? nil : dueDate,
         recurrenceEndDate: resolvedRecurrenceUnit == nil ? nil : recurrenceEndDate,
         locationReminderLatitude: location?.latitude,
         locationReminderLongitude: location?.longitude,
         locationReminderRadius: location == nil ? nil : 150,
         locationReminderTrigger: location?.trigger,
         locationReminderLabel: location?.label,
         tags: selectedTags,
         cloudID: ownerUserID == nil ? nil : UUID(),
         ownerUserID: ownerUserID
      )
      context.insert(toDo)
      toDo.setSelectedTags(selectedTags)
      let nanoDoCreationDate = Date.now
      for (index, title) in uniqueTrimmedValues(nanoDoTitles, limit: 12).enumerated() {
         let nanoDo = NanoDo(
            task: title,
            createdAt: nanoDoCreationDate.addingTimeInterval(Double(index) / 1_000),
            toDo: toDo,
            tag: selectedTags.first,
            cloudID: ownerUserID == nil ? nil : UUID(),
            ownerUserID: ownerUserID
         )
         context.insert(nanoDo)
         toDo.nanoDos.append(nanoDo)
      }
      try context.save()

      if performsMutationSideEffects {
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
#if os(iOS)
         LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
#endif
         if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar) {
            try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
            try context.save()
         }
         SyncCoordinator.shared.scheduleLocalSync()
      }

      return snapshot(for: toDo)
   }

   func create(
      draft: AppleIntelligenceToDoDraft,
      location: ToDoIntentLocation? = nil
   ) async throws -> ToDoIntentSnapshot {
      let context = ModelContext(modelContainer)
      let ownerUserID = visibleOwnerUserID
      let dueDate = draft.dueDate
      let reminderIntent = dueDate == nil ? ToDoReminderIntent.soft : draft.reminderIntent
      let selectedTags = try resolveTags(
         named: draft.tagNames,
         ownerUserID: ownerUserID,
         context: context
      )
      let toDo = ToDo(
         task: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
         notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
         dueDate: dueDate,
         reminderIntent: reminderIntent,
         recurrenceUnit: dueDate == nil ? nil : draft.recurrenceUnit,
         recurrenceInterval: dueDate == nil ? nil : draft.recurrenceInterval,
         recurrenceMode: dueDate == nil ? nil : draft.recurrenceMode,
         recurrenceCount: dueDate == nil ? nil : draft.recurrenceCount,
         recurrenceAnchorDate: dueDate == nil ? nil : dueDate,
         recurrenceEndDate: dueDate == nil ? nil : draft.recurrenceEndDate,
         locationReminderLatitude: location?.latitude,
         locationReminderLongitude: location?.longitude,
         locationReminderRadius: location == nil ? nil : 150,
         locationReminderTrigger: location?.trigger,
         locationReminderLabel: location?.label,
         tags: selectedTags,
         cloudID: ownerUserID == nil ? nil : UUID(),
         ownerUserID: ownerUserID
      )
      context.insert(toDo)
      toDo.setSelectedTags(selectedTags)

      let nanoDoCreationDate = Date.now
      for (index, title) in uniqueTrimmedValues(draft.nanoDoTitles, limit: 12).enumerated() {
         let nanoDo = NanoDo(
            task: title,
            createdAt: nanoDoCreationDate.addingTimeInterval(Double(index) / 1_000),
            toDo: toDo,
            tag: selectedTags.first,
            cloudID: ownerUserID == nil ? nil : UUID(),
            ownerUserID: ownerUserID
         )
         context.insert(nanoDo)
         toDo.nanoDos.append(nanoDo)
      }

      try context.save()
      await performCreationSideEffects(for: toDo, context: context)
      return snapshot(for: toDo)
   }

   func complete(identifier: String) async throws -> ToDoIntentSnapshot? {
      let context = ModelContext(modelContainer)
      let toDos = try context.fetch(FetchDescriptor<ToDo>())
      guard let toDo = toDos.first(where: {
         isVisibleInCurrentScope($0) && self.identifier(for: $0) == identifier
      }) else {
         return nil
      }

      guard toDo.lifecycleState == .active else {
         return snapshot(for: toDo)
      }

      toDo.transition(to: .done)
#if os(iOS)
      LiveActivityService.shared.endActivity(for: toDo)
#endif
      try context.save()

      if performsMutationSideEffects {
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
#if os(iOS)
         LiveActivityService.shared.refresh(from: context)
#endif
         if toDo.calendarEventIdentifier != nil {
            try CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
            try context.save()
         }
         SyncCoordinator.shared.scheduleLocalSync()
      }

      return snapshot(for: toDo)
   }

   func update(
      identifier: String,
      title: String? = nil,
      notes: String? = nil,
      dueDate: Date? = nil,
      clearDueDate: Bool = false,
      reminderIntent: ToDoReminderIntent? = nil,
      tags: [String]? = nil,
      replaceTags: Bool = true,
      nanoDoTitles: [String]? = nil,
      replaceNanoDos: Bool = false,
      clearRecurrence: Bool = false,
      recurrenceUnit: ToDoRecurrenceUnit? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceMode: ToDoRecurrenceMode? = nil,
      recurrenceCount: Int? = nil,
      recurrenceEndDate: Date? = nil,
      location: ToDoIntentLocation? = nil,
      clearLocation: Bool = false
   ) async throws -> ToDoIntentSnapshot? {
      let context = ModelContext(modelContainer)
      guard let toDo = try visibleToDo(identifier: identifier, in: context) else {
         return nil
      }

      if let title {
         let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmedTitle.isEmpty else { throw ToDoIntentRepositoryError.emptyTitle }
         toDo.task = trimmedTitle
      }
      if let notes {
         toDo.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      if clearDueDate {
         toDo.dueDate = nil
         toDo.clearRecurrence()
      } else if let dueDate {
         toDo.dueDate = dueDate
      }
      if clearRecurrence || clearDueDate {
         toDo.clearRecurrence()
      } else if recurrenceUnit != nil || recurrenceInterval != nil || recurrenceMode != nil || recurrenceCount != nil || recurrenceEndDate != nil {
         if toDo.dueDate == nil {
            toDo.clearRecurrence()
         } else {
            toDo.recurrenceUnit = recurrenceUnit ?? toDo.recurrenceUnit ?? .days
            toDo.recurrenceInterval = max(recurrenceInterval ?? toDo.recurrenceInterval ?? 1, 1)
            toDo.recurrenceMode = recurrenceMode ?? toDo.recurrenceMode ?? .continuous
            toDo.recurrenceCount = toDo.recurrenceMode == .finite ? recurrenceCount ?? toDo.recurrenceCount : nil
            toDo.recurrenceAnchorDate = toDo.recurrenceAnchorDate ?? toDo.dueDate
            toDo.recurrenceEndDate = recurrenceEndDate ?? toDo.recurrenceEndDate
         }
      }
      if let reminderIntent {
         toDo.reminderIntent = toDo.dueDate == nil ? .soft : reminderIntent
      }
      if let tags {
         let names = replaceTags ? tags : toDo.effectiveTags.map(\.name) + tags
         let resolvedTags = try resolveTags(named: names, ownerUserID: visibleOwnerUserID, context: context)
         toDo.setSelectedTags(resolvedTags)
      }
      if replaceNanoDos, let nanoDoTitles {
         for nanoDo in toDo.nanoDos {
            context.delete(nanoDo)
         }
         let createdAt = Date.now
         let resolvedTags = toDo.effectiveTags
         let newNanoDos = uniqueTrimmedValues(nanoDoTitles, limit: 12).enumerated().map { index, title in
            NanoDo(
               task: title,
               createdAt: createdAt.addingTimeInterval(Double(index) / 1_000),
               toDo: toDo,
               tag: resolvedTags.first,
               cloudID: visibleOwnerUserID == nil ? nil : UUID(),
               ownerUserID: visibleOwnerUserID
            )
         }
         newNanoDos.forEach(context.insert)
         toDo.nanoDos = newNanoDos
      }

      if clearLocation {
         toDo.clearLocationReminder()
      } else if let location {
         toDo.locationReminderLatitude = location.latitude
         toDo.locationReminderLongitude = location.longitude
         toDo.locationReminderRadius = 150
         toDo.locationReminderTrigger = location.trigger
         toDo.locationReminderLabel = location.label
      }

      toDo.markUpdated()
      try context.save()
      await performMutationSideEffects(for: toDo, context: context, removeCalendarEvent: clearDueDate)
      return snapshot(for: toDo)
   }

   func archive(identifier: String) async throws -> ToDoIntentSnapshot? {
      try await transition(identifier: identifier, to: .archived)
   }

   func trash(identifier: String) async throws -> ToDoIntentSnapshot? {
      try await transition(identifier: identifier, to: .trashed, removeCalendarEvent: true)
   }

   func restore(identifier: String) async throws -> ToDoIntentSnapshot? {
      try await transition(identifier: identifier, to: .active)
   }

   func delete(identifier: String) async throws -> Bool {
      let context = ModelContext(modelContainer)
      guard let toDo = try visibleToDo(identifier: identifier, in: context) else {
         return false
      }

      SyncTombstoneStore.recordDelete(
         table: .toDos,
         recordID: toDo.cloudID,
         userID: toDo.ownerUserID,
         collabID: toDo.collabID
      )
      try? CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
      #if os(iOS)
      LiveActivityService.shared.endActivity(for: toDo)
      #endif
      context.delete(toDo)
      try context.save()

      if performsMutationSideEffects {
         NotificationManager.shared.scheduleRefresh()
         WidgetSnapshotService.shared.writeSnapshot(from: context)
         SyncCoordinator.shared.scheduleLocalSync()
      }
      return true
   }

   func details(identifier: String) throws -> String? {
      let context = ModelContext(modelContainer)
      guard let toDo = try visibleToDo(identifier: identifier, in: context) else { return nil }

      var details = [toDo.task.isEmpty ? String(localized: "Untitled toDō") : toDo.task]
      details.append(String(localized: "Status: \(toDo.lifecycleState.rawValue)"))
      if let dueDate = toDo.dueDate {
         details.append(String(format: String(localized: "Due %@"), dueDate.formatted(date: .abbreviated, time: .shortened)))
      }
      if !toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
         details.append(String(format: String(localized: "Notes: %@"), toDo.notes))
      }
      if !toDo.effectiveTags.isEmpty {
         details.append(String(format: String(localized: "Tags: %@"), toDo.effectiveTags.map(\.displayName).joined(separator: ", ")))
      }
      if !toDo.orderedNanoDos.isEmpty {
         let nanoDos = toDo.orderedNanoDos.map { ($0.isDone ? "✓ " : "") + $0.task }.joined(separator: ", ")
         details.append(String(format: String(localized: "NanoDos: %@"), nanoDos))
      }
      return details.joined(separator: ". ")
   }

   func listDialog(searchText: String? = nil, includeCompleted: Bool = false, limit: Int = 10) throws -> String {
      let context = ModelContext(modelContainer)
      let records = try context.fetch(FetchDescriptor<ToDo>())
         .filter(isVisibleInCurrentScope(_:))
         .filter { includeCompleted || $0.lifecycleState == .active }
         .sorted { ToDo.presentationDueDateSort($0, $1) }
      let normalizedSearchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
      let matching = records.filter { toDo in
         guard let normalizedSearchText, !normalizedSearchText.isEmpty else { return true }
         return toDo.task.localizedLowercase.contains(normalizedSearchText)
      }
      let limited = matching.prefix(max(1, limit))
      guard !limited.isEmpty else { return String(localized: "No matching toDōs found.") }
      let rows = limited.map { toDo in
         if let dueDate = toDo.dueDate {
            return "\(toDo.task) (\(dueDate.formatted(date: .abbreviated, time: .shortened)))"
         }
         return toDo.task
      }
      return rows.joined(separator: ", ")
   }

   private enum ToDoIntentRepositoryError: LocalizedError {
      case emptyTitle

      var errorDescription: String? { String(localized: "A toDō title is required.") }
   }

   private func transition(
      identifier: String,
      to state: ToDoState,
      removeCalendarEvent: Bool = false
   ) async throws -> ToDoIntentSnapshot? {
      let context = ModelContext(modelContainer)
      guard let toDo = try visibleToDo(identifier: identifier, in: context) else { return nil }
      toDo.transition(to: state)
      if removeCalendarEvent || state == .trashed {
         try? CalendarIntegrationService.shared.removeCalendarEvent(for: toDo)
      }
      if state == .trashed {
         #if os(iOS)
         LiveActivityService.shared.endActivity(for: toDo)
         #endif
      }
      try context.save()
      await performMutationSideEffects(for: toDo, context: context, removeCalendarEvent: false)
      return snapshot(for: toDo)
   }

   private func visibleToDo(identifier: String, in context: ModelContext) throws -> ToDo? {
      try context.fetch(FetchDescriptor<ToDo>()).first {
         isVisibleInCurrentScope($0) && self.identifier(for: $0) == identifier
      }
   }

   private func performMutationSideEffects(
      for toDo: ToDo,
      context: ModelContext,
      removeCalendarEvent: Bool
   ) async {
      guard performsMutationSideEffects else { return }
      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
#if os(iOS)
      LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
#endif
      if removeCalendarEvent {
         try? context.save()
      } else if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar), toDo.dueDate != nil {
         do {
            try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
         } catch {
            AppLog.error("App Intent calendar mirror failed: \(error)", logger: AppLog.calendar)
         }
         try? context.save()
      }
      SyncCoordinator.shared.scheduleLocalSync()
   }

   private var visibleOwnerUserID: UUID? {
      guard SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere else { return nil }
#if os(macOS)
      return ToDoMacAuthStore.shared.currentUserID
#else
      return SupabaseAuthStore.shared.scopedOwnerUserID
#endif
   }

   private func resolveTags(
      named rawNames: [String],
      ownerUserID: UUID?,
      context: ModelContext
   ) throws -> [Tag] {
      let requestedNames = uniqueTrimmedValues(
         rawNames.map(Tag.normalizeName(_:)),
         limit: ToDo.maxTagSelection
      )
      guard !requestedNames.isEmpty else { return [] }

      let requestedNameSet = Set(requestedNames)
      let existingTags = try context.fetch(FetchDescriptor<Tag>())
         .filter { $0.ownerUserID == ownerUserID }
         .filter { requestedNameSet.contains(Tag.normalizeName($0.name)) }
      let canonicalByName = Dictionary(
         uniqueKeysWithValues: Tag.canonicalTags(from: existingTags).map {
            (Tag.normalizeName($0.name), $0)
         }
      )

      return requestedNames.map { name in
         if let existing = canonicalByName[name] {
            return existing
         }
         let tag = Tag(
            name: name,
            cloudID: ownerUserID == nil ? nil : UUID(),
            ownerUserID: ownerUserID
         )
         context.insert(tag)
         return tag
      }
   }

   private func uniqueTrimmedValues(_ values: [String], limit: Int) -> [String] {
      var seen = Set<String>()
      var result: [String] = []
      result.reserveCapacity(min(values.count, limit))

      for value in values {
         let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmed.isEmpty else { continue }
         let key = trimmed.localizedLowercase
         guard seen.insert(key).inserted else { continue }
         result.append(trimmed)
         if result.count == limit { break }
      }
      return result
   }

   private func performCreationSideEffects(for toDo: ToDo, context: ModelContext) async {
      guard performsMutationSideEffects else { return }

      NotificationManager.shared.scheduleRefresh()
      WidgetSnapshotService.shared.writeSnapshot(from: context)
#if os(iOS)
      LiveActivityService.shared.refresh(from: context, preferredToDo: toDo)
#endif
      if UserDefaults.standard.bool(forKey: AppPreferences.Keys.mirrorDueDatesToCalendar) {
         do {
            try await CalendarIntegrationService.shared.syncCalendarEvent(for: toDo)
            try context.save()
         } catch {
            AppLog.error("App Intent calendar mirror failed: \(error)", logger: AppLog.app)
         }
      }
      SyncCoordinator.shared.scheduleLocalSync()
   }

   private func isVisibleInCurrentScope(_ toDo: ToDo) -> Bool {
      if toDo.ownerUserID == visibleOwnerUserID {
         return true
      }
      guard let collabID = toDo.collabID else { return false }
      return accessibleCollabIDs.contains(collabID)
   }

   private var accessibleCollabIDs: Set<UUID> {
      accessibleCollabIDsProvider()
   }

   private func identifier(for toDo: ToDo) -> String {
      if let cloudID = toDo.cloudID {
         return "cloud:\(cloudID.uuidString.lowercased())"
      }
      return "local:\(String(describing: toDo.id))"
   }

   private func snapshot(for toDo: ToDo) -> ToDoIntentSnapshot {
      ToDoIntentSnapshot(
         identifier: identifier(for: toDo),
         title: toDo.task.isEmpty ? String(localized: "Untitled toDō") : toDo.task,
         dueDate: toDo.dueDate
      )
   }
}
