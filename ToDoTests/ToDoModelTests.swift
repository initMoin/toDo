import Foundation
import Testing
@testable import ToDo

@Suite("ToDo model foundation")
@MainActor
struct ToDoModelTests {
   @Test
   func completingEveryNanoDoCanCompleteParent() {
      let toDo = ToDo(
         task: "Ship update",
         completeWhenAllNanoDosDone: true
      )
      let first = NanoDo(task: "Screenshots", isDone: true, toDo: toDo)
      let second = NanoDo(task: "Release notes", isDone: false, toDo: toDo)
      toDo.nanoDos = [first, second]

      #expect(!toDo.completeIfAllNanoDosAreDone())
      #expect(toDo.isActive)

      second.isDone = true

      #expect(toDo.completeIfAllNanoDosAreDone())
      #expect(toDo.lifecycleState == .done)
   }

   @Test
   func completingNanoDosDoesNotCompleteParentWhenPreferenceIsOff() {
      let toDo = ToDo(
         task: "Ship update",
         completeWhenAllNanoDosDone: false
      )
      toDo.nanoDos = [
         NanoDo(task: "Screenshots", isDone: true, toDo: toDo),
         NanoDo(task: "Release notes", isDone: true, toDo: toDo)
      ]

      #expect(!toDo.completeIfAllNanoDosAreDone())
      #expect(toDo.isActive)
   }

   @Test
   func emptyNanoDoListNeverCompletesParent() {
      let toDo = ToDo(
         task: "Ship update",
         completeWhenAllNanoDosDone: true
      )

      #expect(!toDo.completeIfAllNanoDosAreDone())
      #expect(toDo.isActive)
   }

   @Test
   func completedParentIsNotCompletedAgain() {
      let toDo = ToDo(
         task: "Ship update",
         lifecycleState: .done,
         completeWhenAllNanoDosDone: true
      )
      toDo.nanoDos = [
         NanoDo(task: "Screenshots", isDone: true, toDo: toDo)
      ]

      #expect(!toDo.completeIfAllNanoDosAreDone())
      #expect(toDo.lifecycleState == .done)
   }

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

   @Test func finiteRecurrenceRequiresPositiveCount() {
      let toDo = ToDo(
         task: "Repeat twice",
         dueDate: Date(),
         recurrenceUnit: .weeks,
         recurrenceInterval: 1,
         recurrenceMode: .finite,
         recurrenceCount: 0
      )

      #expect(!toDo.isRecurring)
      #expect(toDo.recurrenceSummary == nil)

      toDo.recurrenceCount = 2

      #expect(toDo.isRecurring)
      #expect(toDo.recurrenceSummary == "Every 1 week for 2 additional times")
   }

   @Test func continuousRecurrenceIgnoresCountButRequiresPositiveInterval() {
      let toDo = ToDo(
         task: "Keep checking",
         dueDate: Date(),
         recurrenceUnit: .hours,
         recurrenceInterval: 0,
         recurrenceMode: .continuous,
         recurrenceCount: nil
      )

      #expect(!toDo.isRecurring)
      #expect(toDo.recurrenceSummary == nil)

      toDo.recurrenceInterval = 3

      #expect(toDo.isRecurring)
      #expect(toDo.recurrenceSummary == "Every 3 hours continuously")
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

   @Test func todoTransitionToTrashedCapturesTimestamp() {
      let toDo = ToDo(task: "Recycle electronics")
      let now = Date()

      #expect(toDo.lifecycleState == .active)
      #expect(toDo.trashedAt == nil)

      toDo.trashedAt = now
      toDo.transition(to: .trashed)

      #expect(toDo.lifecycleState == .trashed)
      #expect(toDo.trashedAt == now)
   }

   @Test func restoringFromTrashClearsTimestamp() {
      let toDo = ToDo(task: "Save this task")
      toDo.trashedAt = Date()
      toDo.transition(to: .trashed)

      toDo.transition(to: .active)
      toDo.trashedAt = nil

      #expect(toDo.lifecycleState == .active)
      #expect(toDo.trashedAt == nil)
   }
}

@Suite("Guided onboarding state")
@MainActor
struct GuidedOnboardingManagerTests {
   @Test
   func firstRunCannotSkipOnboarding() throws {
      let defaults = try makeDefaults()
      let manager = GuidedOnboardingManager(defaults: defaults)

      #expect(manager.isActive)
      #expect(manager.currentStep == .welcome)
      #expect(!manager.canSkip)
   }

   @Test
   func replayCanBeSkippedAfterPriorCompletion() throws {
      let defaults = try makeDefaults()
      defaults.set(true, forKey: AppPreferences.Keys.didCompleteOnboarding)
      defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboardingOnce)
      let manager = GuidedOnboardingManager(defaults: defaults)

      manager.restart()

      #expect(manager.isActive)
      #expect(manager.currentStep == .welcome)
      #expect(manager.canSkip)
   }

   @Test
   func resumesFromSavedStep() throws {
      let defaults = try makeDefaults()
      defaults.set(
         GuidedOnboardingStep.notificationPermission.rawValue,
         forKey: AppPreferences.Keys.currentOnboardingStep
      )
      let manager = GuidedOnboardingManager(defaults: defaults)

      #expect(manager.isActive)
      #expect(manager.currentStep == .notificationPermission)
   }

   @Test
   func invalidSavedStepRestartsAtWelcome() throws {
      let defaults = try makeDefaults()
      defaults.set("removed-step", forKey: AppPreferences.Keys.currentOnboardingStep)
      let manager = GuidedOnboardingManager(defaults: defaults)

      #expect(manager.isActive)
      #expect(manager.currentStep == .welcome)
      #expect(
         defaults.string(forKey: AppPreferences.Keys.currentOnboardingStep)
            == GuidedOnboardingStep.welcome.rawValue
      )
   }

   @Test
   func completionPersistsAndClearsResumeState() throws {
      let defaults = try makeDefaults()
      let manager = GuidedOnboardingManager(defaults: defaults)

      manager.complete()

      #expect(!manager.isActive)
      #expect(defaults.bool(forKey: AppPreferences.Keys.didCompleteOnboarding))
      #expect(defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboardingOnce))
      #expect(defaults.string(forKey: AppPreferences.Keys.currentOnboardingStep) == nil)
   }

   private func makeDefaults() throws -> UserDefaults {
      let suiteName = "GuidedOnboardingManagerTests.\(UUID().uuidString)"
      let defaults = try #require(UserDefaults(suiteName: suiteName))
      defaults.removePersistentDomain(forName: suiteName)
      return defaults
   }
}
