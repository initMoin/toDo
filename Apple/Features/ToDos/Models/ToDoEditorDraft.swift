import Foundation
import SwiftData

struct ToDoEditorNanoDoDraft: Identifiable, Equatable {
   let id: UUID
   var existingID: PersistentIdentifier?
   var task: String
   var isDone: Bool
   var hasDueDate: Bool
   var dueDate: Date

   init(
      id: UUID = UUID(),
      existingID: PersistentIdentifier? = nil,
      task: String = "",
      isDone: Bool = false,
      hasDueDate: Bool = false,
      dueDate: Date = .now.addingTimeInterval(60 * 60)
   ) {
      self.id = id
      self.existingID = existingID
      self.task = task
      self.isDone = isDone
      self.hasDueDate = hasDueDate
      self.dueDate = dueDate
   }

   init(nanoDo: NanoDo) {
      self.init(
         existingID: nanoDo.id,
         task: nanoDo.task,
         isDone: nanoDo.isDone,
         hasDueDate: nanoDo.dueDate != nil,
         dueDate: nanoDo.dueDate ?? .now.addingTimeInterval(60 * 60)
      )
   }
}

struct ToDoEditorDraft {
   var task: String
   var notes: String
   var hasDueDate: Bool
   var dueDate: Date
   var reminderIntent: ToDoReminderIntent
   var completeWhenAllNanoDosDone: Bool
   var collabID: UUID?
   var selectedTagIDs: Set<PersistentIdentifier>
   var nanoDos: [ToDoEditorNanoDoDraft]

   init(toDo: ToDo? = nil) {
      task = toDo?.task ?? ""
      notes = toDo?.notes ?? ""
      hasDueDate = toDo?.dueDate != nil
      dueDate = toDo?.dueDate ?? .now.addingTimeInterval(60 * 60)
      reminderIntent = toDo?.reminderIntent ?? .due
      completeWhenAllNanoDosDone = toDo?.completeWhenAllNanoDosDone ?? false
      collabID = toDo?.collabID
      selectedTagIDs = Set(toDo?.effectiveTags.map(\.id) ?? [])
      nanoDos = toDo?.orderedNanoDos.map(ToDoEditorNanoDoDraft.init(nanoDo:)) ?? []
   }

   var trimmedTask: String {
      task.trimmingCharacters(in: .whitespacesAndNewlines)
   }

   var canSave: Bool {
      !trimmedTask.isEmpty
   }

   func selectedTags(from availableTags: [Tag]) -> [Tag] {
      var seenNames = Set<String>()
      var resolved: [Tag] = []

      for tag in availableTags where selectedTagIDs.contains(tag.id) {
         let normalizedName = Tag.normalizeName(tag.name)
         guard seenNames.insert(normalizedName).inserted else { continue }
         resolved.append(tag)
         if resolved.count == ToDo.maxTagSelection { break }
      }

      return resolved
   }

   mutating func toggleTag(_ tag: Tag) {
      if selectedTagIDs.contains(tag.id) {
         selectedTagIDs.remove(tag.id)
      } else if selectedTagIDs.count < ToDo.maxTagSelection {
         selectedTagIDs.insert(tag.id)
      }
   }

   @discardableResult
   mutating func selectOrCreateTag(
      named rawName: String,
      availableTags: [Tag],
      ownerUserID: UUID? = nil,
      context: ModelContext
   ) -> Tag? {
      let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedName.isEmpty else { return nil }

      let normalizedName = Tag.normalizeName(trimmedName)
      let resolvedTag: Tag
      if let existing = availableTags
         .filter({ Tag.normalizeName($0.name) == normalizedName })
         .sorted(by: { lhs, rhs in
            Tag.shouldPreferCanonical(lhs, over: rhs)
         })
         .first {
         resolvedTag = existing
      } else {
         let tag = Tag(
            name: normalizedName,
            cloudID: ownerUserID == nil ? nil : UUID(),
            ownerUserID: ownerUserID
         )
         context.insert(tag)
         resolvedTag = tag
      }

      if selectedTagIDs.count < ToDo.maxTagSelection {
         selectedTagIDs.insert(resolvedTag.id)
      }
      return resolvedTag
   }

   @discardableResult
   func save(
      existingToDo: ToDo?,
      availableTags: [Tag],
      ownerUserID: UUID? = nil,
      context: ModelContext
   ) throws -> ToDo {
      let trimmedTask = trimmedTask
      guard !trimmedTask.isEmpty else {
         throw ToDoEditorDraftError.emptyTask
      }

      let toDo: ToDo
      if let existingToDo {
         toDo = existingToDo
         toDo.task = trimmedTask
         toDo.notes = notes
         toDo.dueDate = hasDueDate ? dueDate : nil
         toDo.reminderIntent = hasDueDate ? reminderIntent : .soft
         toDo.completeWhenAllNanoDosDone = completeWhenAllNanoDosDone
         toDo.collabID = collabID
         toDo.setSelectedTags(selectedTags(from: availableTags))
         reconcileNanoDos(for: toDo, ownerUserID: ownerUserID, context: context)
         toDo.markUpdated()
      } else {
         toDo = ToDo(
            task: trimmedTask,
            notes: notes,
            dueDate: hasDueDate ? dueDate : nil,
            reminderIntent: hasDueDate ? reminderIntent : .soft,
            completeWhenAllNanoDosDone: completeWhenAllNanoDosDone,
            cloudID: ownerUserID == nil ? nil : UUID(),
            ownerUserID: ownerUserID,
            collabID: collabID
         )
         context.insert(toDo)
         toDo.setSelectedTags(selectedTags(from: availableTags))
         reconcileNanoDos(for: toDo, ownerUserID: ownerUserID, context: context)
      }

      try context.save()
      return toDo
   }

   private func reconcileNanoDos(for toDo: ToDo, ownerUserID: UUID?, context: ModelContext) {
      let existingByID = Dictionary(uniqueKeysWithValues: toDo.nanoDos.map { ($0.id, $0) })
      var nextNanoDos: [NanoDo] = []
      var retainedIDs = Set<PersistentIdentifier>()

      for draft in nanoDos {
         let trimmedTask = draft.task.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmedTask.isEmpty else { continue }

         let nanoDo: NanoDo
         if let existingID = draft.existingID, let existing = existingByID[existingID] {
            nanoDo = existing
            retainedIDs.insert(existingID)
         } else {
            nanoDo = NanoDo(
               task: trimmedTask,
               toDo: toDo,
               cloudID: ownerUserID == nil ? nil : UUID(),
               ownerUserID: ownerUserID
            )
            context.insert(nanoDo)
         }

         nanoDo.task = trimmedTask
         nanoDo.isDone = draft.isDone
         nanoDo.dueDate = draft.hasDueDate ? draft.dueDate : nil
         nanoDo.toDo = toDo
         nextNanoDos.append(nanoDo)
      }

      for existing in toDo.nanoDos where !retainedIDs.contains(existing.id) && existingByID[existing.id] != nil {
         context.delete(existing)
      }

      toDo.nanoDos = nextNanoDos
   }
}

enum ToDoEditorDraftError: Error {
   case emptyTask
}
