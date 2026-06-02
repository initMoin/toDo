import Foundation
import Testing
@testable import ToDo

@Suite("Free feature contract")
@MainActor
struct FreeFeatureContractTests {
    @Test func personalSyncModesRemainAvailableWithoutPaidEntitlements() {
        #expect(SyncMode.deviceOnly.title == "This Device Only")
        #expect(SyncMode.iCloud.title == "Sync with iCloud")
        #expect(SyncMode.syncEverywhere.title == "toDō Sync")
        #expect(SyncMode.allCases == [.deviceOnly, .iCloud, .syncEverywhere])
    }

    @Test func currentPersonalSortingAndGroupingOptionsRemainCoreFeatures() {
        #expect(AppPreferences.ToDoListSortOption.orderingOptions == [.dueDate, .creationDate, .tag])
        #expect(AppPreferences.ToDoListSortOption.groupingOptions == [.dueMonthSections, .tagSections, .nanoDoSections])
    }

    @Test func reminderIntentsRemainCoreFeatures() {
        #expect(ToDoReminderIntent.allCases == [.soft, .due, .timeSensitive])
        #expect(ToDoReminderIntent.soft.title == "Quiet")
        #expect(ToDoReminderIntent.due.title == "Due")
        #expect(ToDoReminderIntent.timeSensitive.title == "Time-Sensitive")
    }

    @Test func recurrenceCadencesRemainCoreFeatures() {
        #expect(ToDoRecurrenceUnit.allCases == [.seconds, .minutes, .hours, .days, .weeks, .months, .years])
        #expect(ToDoRecurrenceMode.allCases == [.finite, .continuous])
    }

    @Test func continuousAndFiniteRecurrenceRemainAvailableWithoutPaidEntitlements() {
        let dueDate = Date(timeIntervalSinceReferenceDate: 1_000)
        let continuousToDo = ToDo(
            task: "Hydrate",
            dueDate: dueDate,
            recurrenceUnit: .hours,
            recurrenceInterval: 6,
            recurrenceMode: .continuous
        )
        let finiteToDo = ToDo(
            task: "Quarterly review",
            dueDate: dueDate,
            recurrenceUnit: .months,
            recurrenceInterval: 3,
            recurrenceMode: .finite,
            recurrenceCount: 2
        )

        #expect(continuousToDo.isRecurring)
        #expect(continuousToDo.recurrenceSummary == "Every 6 hours continuously")
        #expect(finiteToDo.isRecurring)
        #expect(finiteToDo.recurrenceSummary == "Every 3 months for 2 additional times")
    }
}
