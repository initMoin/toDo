import Foundation
import Testing
@testable import ToDo

@Suite("ToDo model foundation")
@MainActor
struct ToDoModelTests {
    @Test func untaggedToDoHasNoEffectiveTagsWithoutRecursion() {
        let toDo = ToDo(task: "Plan week")

        #expect(toDo.tag == nil)
        #expect(toDo.tags.isEmpty)
        #expect(toDo.effectiveTags.isEmpty)
    }

    @Test func selectedTagsAreDeduplicatedAndCapped() {
        let tags = (0..<7).map { Tag(name: "tag-\($0)") }
        let toDo = ToDo(task: "Organize", tags: tags + [tags[0]])

        #expect(toDo.effectiveTags.count == ToDo.maxTagSelection)
        #expect(toDo.effectiveTags.map(\.displayName) == ["tag-0", "tag-1", "tag-2", "tag-3", "tag-4"])
        #expect(toDo.tag?.displayName == "tag-0")
    }

    @Test func settingLegacyPrimaryTagStillContributesToEffectiveTags() {
        let tag = Tag(name: "legacy")
        let toDo = ToDo(task: "Imported")

        toDo.tag = tag

        #expect(toDo.tags.isEmpty)
        #expect(toDo.effectiveTags.map(\.displayName) == ["legacy"])
    }

    @Test func recurrenceRequiresDueDateAndValidCadence() {
        let toDo = ToDo(
            task: "Repeat",
            dueDate: Date(),
            recurrenceUnit: .days,
            recurrenceInterval: 1,
            recurrenceMode: .finite,
            recurrenceCount: 1
        )

        #expect(toDo.isRecurring)
        #expect(toDo.recurrenceSummary == "Every 1 day for 1 additional time")

        toDo.dueDate = nil

        #expect(!toDo.isRecurring)
        #expect(toDo.recurrenceSummary == nil)
    }

    @Test func updatedAtTracksDomainMutations() {
        let createdAt = Date(timeIntervalSinceReferenceDate: 100)
        let updatedAt = Date(timeIntervalSinceReferenceDate: 200)
        let toDo = ToDo(task: "Resolve conflict", createdAt: createdAt, updatedAt: updatedAt)

        #expect(toDo.updatedAt == updatedAt)

        let nextUpdate = Date(timeIntervalSinceReferenceDate: 300)
        toDo.markUpdated(nextUpdate)

        #expect(toDo.updatedAt == nextUpdate)
    }
}
