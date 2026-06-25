import Foundation
import Testing
@testable import ToDo

struct AppleIntelligenceToDoParserTests {
   @MainActor
   @Test
   func validatesStructuredDirectivesAgainstOriginalRequest() throws {
      let request = """
      Submit version 3.1 Friday, June 26, 2026 at 4 PM. Make it time-sensitive, tag it development, \
      note that TestFlight must be verified, and add screenshots and release notes as steps.
      """
      let modelResponse = """
      {
        "title": "Submit version 3.1",
        "notes": "Tag: development. Note: TestFlight must be verified. Steps: add screenshots, add release notes.",
        "dueDate": "2026-06-23T16:00:00-05:00",
        "reminderIntent": "timeSensitive",
        "recurrenceUnit": "days",
        "recurrenceInterval": 1,
        "recurrenceMode": "finite",
        "recurrenceCount": 1,
        "recurrenceEndDate": "2026-06-24T16:00:00-05:00",
        "tagNames": ["development"],
        "nanoDoTitles": ["Add screenshots", "Add release notes"],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )
      let expectedDueDate = try #require(
         Calendar.current.date(
            from: DateComponents(
               timeZone: .current,
               year: 2026,
               month: 6,
               day: 26,
               hour: 16
            )
         )
      )

      #expect(draft.title == "Submit version 3.1")
      #expect(draft.dueDate == expectedDueDate)
      #expect(draft.reminderIntent == .timeSensitive)
      #expect(draft.recurrenceUnit == nil)
      #expect(draft.recurrenceInterval == nil)
      #expect(draft.recurrenceMode == nil)
      #expect(draft.recurrenceCount == nil)
      #expect(draft.recurrenceEndDate == nil)
      #expect(draft.tagNames == ["development"])
      #expect(draft.nanoDoTitles == ["Add screenshots", "Add release notes"])
      #expect(draft.notes == "TestFlight must be verified")
   }

   @MainActor
   @Test
   func keepsRecurrenceOnlyWhenTheRequestExplicitlyAsksForIt() throws {
      let request = "Review metrics every Friday at 9 AM for 4 weeks."
      let modelResponse = """
      {
        "title": "Review metrics",
        "notes": "",
        "dueDate": "2026-06-26T09:00:00-05:00",
        "reminderIntent": "due",
        "recurrenceUnit": "weeks",
        "recurrenceInterval": 1,
        "recurrenceMode": "finite",
        "recurrenceCount": 4,
        "recurrenceEndDate": "2026-07-24T09:00:00-05:00",
        "tagNames": [],
        "nanoDoTitles": [],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.recurrenceUnit == .weeks)
      #expect(draft.recurrenceInterval == 1)
      #expect(draft.recurrenceMode == .finite)
      #expect(draft.recurrenceCount == 4)
      #expect(draft.recurrenceEndDate != nil)
   }

   @MainActor
   @Test
   func separatesTagsNotesAndNanoDosWithoutDuplicatingThem() throws {
      let request = """
      Prepare launch plan, tag it development and release, note that legal must approve it, \
      and add draft announcement and verify screenshots as steps.
      """
      let modelResponse = """
      {
        "title": "Prepare launch plan",
        "notes": "legal must approve it",
        "dueDate": null,
        "reminderIntent": "soft",
        "recurrenceUnit": null,
        "recurrenceInterval": null,
        "recurrenceMode": null,
        "recurrenceCount": null,
        "recurrenceEndDate": null,
        "tagNames": ["development", "release", "DEVELOPMENT"],
        "nanoDoTitles": ["Draft announcement", "Verify screenshots", "Draft announcement"],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.notes == "legal must approve it")
      #expect(draft.tagNames == ["development", "release"])
      #expect(draft.nanoDoTitles == ["Draft announcement", "Verify screenshots"])
   }

   @MainActor
   @Test
   func movesExplicitSubtasksOutOfNotesAndIntoNanoDos() throws {
      let request = """
      Complete my report by next week with 3 subtasks: gather metrics, write the summary, and review formatting.
      """
      let modelResponse = """
      {
        "title": "Complete my report",
        "notes": "Gather metrics, write the summary, and review formatting.",
        "dueDate": null,
        "reminderIntent": "soft",
        "recurrenceUnit": null,
        "recurrenceInterval": null,
        "recurrenceMode": null,
        "recurrenceCount": null,
        "recurrenceEndDate": null,
        "tagNames": [],
        "nanoDoTitles": [],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.notes.isEmpty)
      #expect(draft.dueDate != nil)
      #expect(draft.nanoDoTitles == ["gather metrics", "write the summary", "review formatting"])
   }

   @MainActor
   @Test
   func doesNotInventUnnamedSubtasksOrStoreThemAsNotes() throws {
      let request = "Complete my report by next week, with 3 subtasks to be completed."
      let modelResponse = """
      {
        "title": "Complete my report",
        "notes": "3 subtasks to be completed",
        "dueDate": null,
        "reminderIntent": "soft",
        "recurrenceUnit": null,
        "recurrenceInterval": null,
        "recurrenceMode": null,
        "recurrenceCount": null,
        "recurrenceEndDate": null,
        "tagNames": [],
        "nanoDoTitles": [],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.notes.isEmpty)
      #expect(draft.dueDate != nil)
      #expect(draft.nanoDoTitles.isEmpty)
   }

   @MainActor
   @Test
   func explicitSubtaskNamesOverrideInventedModelPlaceholders() throws {
      let request = """
      I want to complete my report by next week, with 2 sub tasks to be completed - flip the script and win the ball game.
      """
      let modelResponse = """
      {
        "title": "Complete report by next week",
        "notes": "",
        "dueDate": null,
        "reminderIntent": "soft",
        "recurrenceUnit": null,
        "recurrenceInterval": null,
        "recurrenceMode": null,
        "recurrenceCount": null,
        "recurrenceEndDate": null,
        "tagNames": [],
        "nanoDoTitles": ["complete report", "complete sub task 1", "complete sub task 2"],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.nanoDoTitles == ["flip the script", "win the ball game"])
      #expect(draft.dueDate != nil)
   }

   @MainActor
   @Test
   func resolvesCommonRelativeDuePhrasesWithoutModelDueDate() throws {
      let request = "Finish the report by next week."
      let modelResponse = """
      {
        "title": "Finish the report",
        "notes": "",
        "dueDate": null,
        "reminderIntent": "soft",
        "recurrenceUnit": null,
        "recurrenceInterval": null,
        "recurrenceMode": null,
        "recurrenceCount": null,
        "recurrenceEndDate": null,
        "tagNames": [],
        "nanoDoTitles": [],
        "locationLabel": null,
        "locationTrigger": null
      }
      """

      let draft = try #require(
         AppleIntelligenceService.decodeToDoDraft(
            from: modelResponse,
            spokenRequest: request
         )
      )

      #expect(draft.dueDate != nil)
   }

   @MainActor
   @Test
   func rejectsMalformedModelOutput() {
      let draft = AppleIntelligenceService.decodeToDoDraft(
         from: "This is not JSON.",
         spokenRequest: "Prepare launch plan"
      )

      #expect(draft == nil)
   }
}
