import Foundation
import SwiftData
import Testing
@testable import ToDo

@MainActor
private final class IntentCollabScopeState {
   var identifiers: Set<UUID>

   init(_ identifiers: Set<UUID>) {
      self.identifiers = identifiers
   }
}

@Suite("App Intent repository")
@MainActor
struct ToDoIntentRepositoryTests {
   @Test func createPersistsAVisibleTimeSensitiveToDo() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let dueDate = Date(timeIntervalSinceReferenceDate: 12_345)

      let created = try await repository.create(
         title: "Ship 3.1",
         dueDate: dueDate,
         isTimeSensitive: true
      )

      let persisted = try #require(container.mainContext.fetch(FetchDescriptor<ToDo>()).first)
      #expect(created.title == "Ship 3.1")
      #expect(created.dueDate == dueDate)
      #expect(persisted.task == "Ship 3.1")
      #expect(persisted.dueDate == dueDate)
      #expect(persisted.reminderIntent == .timeSensitive)
      #expect(persisted.lifecycleState == .active)
   }

   @Test func queryReturnsOnlyMatchingActiveToDosInCurrentScope() throws {
      let container = try makeContainer()
      let context = container.mainContext
      context.insert(ToDo(task: "Write release notes"))
      context.insert(ToDo(task: "Archive old screenshots", lifecycleState: .done))
      context.insert(ToDo(task: "Prepare App Store screenshots"))
      try context.save()

      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let matches = try repository.activeToDos(matching: "release")

      #expect(matches.map(\.title) == ["Write release notes"])
   }

   @Test func queryIncludesOnlyAuthorizedCollabToDos() throws {
      let container = try makeContainer()
      let context = container.mainContext
      let accessibleCollabID = UUID()
      context.insert(ToDo(task: "Personal", ownerUserID: nil))
      context.insert(ToDo(task: "Shared", ownerUserID: UUID(), collabID: accessibleCollabID))
      context.insert(ToDo(task: "Private", ownerUserID: UUID(), collabID: UUID()))
      try context.save()

      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false,
         accessibleCollabIDsProvider: { [accessibleCollabID] }
      )

      #expect(try repository.activeToDos(limit: 10).map(\.title).sorted() == ["Personal", "Shared"])
   }

   @Test func changingCollabScopeDoesNotLeakPriorAccountRecords() throws {
      let container = try makeContainer()
      let context = container.mainContext
      let firstCollabID = UUID()
      let secondCollabID = UUID()
      context.insert(ToDo(task: "First account", ownerUserID: UUID(), collabID: firstCollabID))
      context.insert(ToDo(task: "Second account", ownerUserID: UUID(), collabID: secondCollabID))
      try context.save()

      let activeCollabs = IntentCollabScopeState([firstCollabID])
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false,
         accessibleCollabIDsProvider: { activeCollabs.identifiers }
      )

      #expect(try repository.activeToDos().map(\.title) == ["First account"])
      activeCollabs.identifiers = [secondCollabID]
      #expect(try repository.activeToDos().map(\.title) == ["Second account"])
      activeCollabs.identifiers = []
      #expect(try repository.activeToDos().isEmpty)
   }

   @Test func completeTransitionsTheSelectedToDoToDone() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let created = try await repository.create(
         title: "Verify TestFlight",
         dueDate: nil,
         isTimeSensitive: false
      )

      let completed = try #require(try await repository.complete(identifier: created.identifier))
      let persisted = try #require(container.mainContext.fetch(FetchDescriptor<ToDo>()).first)

      #expect(completed.identifier == created.identifier)
      #expect(persisted.lifecycleState == .done)
      #expect(persisted.isDone)
   }

   @Test func structuredCreatePersistsEditorProperties() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let dueDate = Date(timeIntervalSinceReferenceDate: 25_000)
      let created = try await repository.create(
         title: "Prepare launch",
         dueDate: dueDate,
         isTimeSensitive: false,
         notes: "Check the release checklist.",
         reminderIntent: .due,
         tagNames: ["release", "Release", "qa"],
         nanoDoTitles: ["Capture screenshots", "Write notes", "Capture screenshots"],
         recurrenceUnit: .weeks,
         recurrenceInterval: 1,
         recurrenceMode: .finite,
         recurrenceCount: 2,
         recurrenceEndDate: dueDate.addingTimeInterval(14 * 24 * 60 * 60)
      )

      let persisted = try #require(
         container.mainContext.fetch(FetchDescriptor<ToDo>()).first
      )
      #expect(created.title == "Prepare launch")
      #expect(persisted.notes == "Check the release checklist.")
      #expect(persisted.reminderIntent == .due)
      #expect(persisted.effectiveTags.map(\.name) == ["release", "qa"])
      #expect(persisted.orderedNanoDos.map(\.task) == ["Capture screenshots", "Write notes"])
      #expect(persisted.recurrenceUnit == .weeks)
      #expect(persisted.recurrenceInterval == 1)
      #expect(persisted.recurrenceMode == .finite)
      #expect(persisted.recurrenceCount == 2)
   }

   @Test func updateReplacesStructuredPropertiesAndCanClearRecurrence() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let created = try await repository.create(
         title: "Prepare launch",
         dueDate: Date(timeIntervalSinceReferenceDate: 30_000),
         isTimeSensitive: false,
         notes: "Old notes",
         tagNames: ["old"],
         nanoDoTitles: ["Old step"],
         recurrenceUnit: .days,
         recurrenceInterval: 1,
         recurrenceMode: .continuous
      )

      _ = try await repository.update(
         identifier: created.identifier,
         title: "Prepare launch checklist",
         notes: "New notes",
         reminderIntent: .timeSensitive,
         tags: ["new"],
         replaceTags: true,
         nanoDoTitles: ["New step", "Second step"],
         replaceNanoDos: true,
         clearRecurrence: true
      )

      let persisted = try #require(
         container.mainContext.fetch(FetchDescriptor<ToDo>()).first
      )
      #expect(persisted.task == "Prepare launch checklist")
      #expect(persisted.notes == "New notes")
      #expect(persisted.reminderIntent == .timeSensitive)
      #expect(persisted.effectiveTags.map(\.name) == ["new"])
      #expect(persisted.orderedNanoDos.map(\.task) == ["New step", "Second step"])
      #expect(persisted.recurrenceUnit == nil)
      #expect(persisted.recurrenceInterval == nil)
      #expect(persisted.recurrenceMode == nil)
   }

   @Test func lifecycleActionsAreReversibleUntilPermanentDelete() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let created = try await repository.create(
         title: "Lifecycle test",
         dueDate: nil,
         isTimeSensitive: false
      )

      let archived = try await repository.archive(identifier: created.identifier)
      #expect(archived?.title == "Lifecycle test")
      let archivedState = try container.mainContext.fetch(FetchDescriptor<ToDo>()).first?.lifecycleState
      #expect(archivedState == .archived)
      let restored = try await repository.restore(identifier: created.identifier)
      #expect(restored?.title == "Lifecycle test")
      let restoredState = try container.mainContext.fetch(FetchDescriptor<ToDo>()).first?.lifecycleState
      #expect(restoredState == .active)
      let trashed = try await repository.trash(identifier: created.identifier)
      #expect(trashed?.title == "Lifecycle test")
      let trashedState = try container.mainContext.fetch(FetchDescriptor<ToDo>()).first?.lifecycleState
      #expect(trashedState == .trashed)
      let wasDeleted = try await repository.delete(identifier: created.identifier)
      #expect(wasDeleted)
      let remainingToDos = try container.mainContext.fetch(FetchDescriptor<ToDo>())
      #expect(remainingToDos.isEmpty)
   }

   @Test func intelligentCreatePersistsTheCompleteStructuredToDo() async throws {
      let container = try makeContainer()
      let repository = ToDoIntentRepository(
         modelContainer: container,
         performsMutationSideEffects: false
      )
      let dueDate = Date(timeIntervalSinceReferenceDate: 50_000)
      let draft = AppleIntelligenceToDoDraft(
         title: "Ship toDō 3.1",
         notes: "Verify TestFlight before release.",
         dueDate: dueDate,
         reminderIntent: .timeSensitive,
         recurrenceUnit: .weeks,
         recurrenceInterval: 1,
         recurrenceMode: .finite,
         recurrenceCount: 2,
         recurrenceEndDate: dueDate.addingTimeInterval(14 * 24 * 60 * 60),
         tagNames: ["development", "Development", "release"],
         nanoDoTitles: ["Capture screenshots", "Write release notes", "Capture screenshots"],
         locationLabel: "Studio",
         locationTrigger: .arriving,
         clarificationQuestion: nil
      )
      let location = ToDoIntentLocation(
         latitude: 40.7128,
         longitude: -74.006,
         label: "Studio",
         trigger: .arriving
      )

      _ = try await repository.create(draft: draft, location: location)

      let persisted = try #require(container.mainContext.fetch(FetchDescriptor<ToDo>()).first)
      #expect(persisted.task == "Ship toDō 3.1")
      #expect(persisted.notes == "Verify TestFlight before release.")
      #expect(persisted.dueDate == dueDate)
      #expect(persisted.reminderIntent == .timeSensitive)
      #expect(persisted.recurrenceUnit == .weeks)
      #expect(persisted.recurrenceInterval == 1)
      #expect(persisted.recurrenceMode == .finite)
      #expect(persisted.recurrenceCount == 2)
      #expect(Set(persisted.effectiveTags.map(\.name)) == ["development", "release"])
      #expect(persisted.orderedNanoDos.map(\.task) == ["Capture screenshots", "Write release notes"])
      #expect(persisted.locationReminderLatitude == 40.7128)
      #expect(persisted.locationReminderLongitude == -74.006)
      #expect(persisted.locationReminderLabel == "Studio")
      #expect(persisted.locationReminderTrigger == .arriving)
   }

   private func makeContainer() throws -> ModelContainer {
      let configuration = ModelConfiguration(
         UUID().uuidString,
         isStoredInMemoryOnly: true,
         cloudKitDatabase: .none
      )
      return try ModelContainer(
         for: ToDo.self,
         Tag.self,
         NanoDo.self,
         SyncConflict.self,
         configurations: configuration
      )
   }
}
