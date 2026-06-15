import EventKit
import Foundation
import SwiftData

@MainActor
final class CalendarIntegrationService {
   static let shared = CalendarIntegrationService()

   private let eventStore = EKEventStore()

   private init() {}

   func requestWriteAccess() async throws -> Bool {
      if #available(iOS 17.0, *) {
         return try await eventStore.requestWriteOnlyAccessToEvents()
      } else {
         return try await eventStore.requestAccess(to: .event)
      }
   }

   @discardableResult
   func syncCalendarEvent(for toDo: ToDo) async throws -> String? {
      guard toDo.isActive, let dueDate = toDo.dueDate else {
         try removeCalendarEvent(for: toDo)
         return nil
      }

      let authorized = try await requestWriteAccess()
      guard authorized else { return nil }

      let event: EKEvent
      if let eventIdentifier = toDo.calendarEventIdentifier,
         let existingEvent = eventStore.event(withIdentifier: eventIdentifier) {
         event = existingEvent
      } else {
         event = EKEvent(eventStore: eventStore)
      }

      event.title = toDo.task.isEmpty ? "toDō" : toDo.task
      event.notes = calendarNotes(for: toDo)
      event.startDate = dueDate
      event.endDate = max(dueDate.addingTimeInterval(30 * 60), dueDate.addingTimeInterval(60))
      event.calendar = eventStore.defaultCalendarForNewEvents
      event.recurrenceRules = recurrenceRules(for: toDo)

      try eventStore.save(event, span: event.recurrenceRules?.isEmpty == false ? .futureEvents : .thisEvent, commit: true)
      toDo.calendarEventIdentifier = event.eventIdentifier
      return event.eventIdentifier
   }

   func removeCalendarEvent(for toDo: ToDo) throws {
      guard let eventIdentifier = toDo.calendarEventIdentifier else { return }

      if let event = eventStore.event(withIdentifier: eventIdentifier) {
         try eventStore.remove(event, span: event.recurrenceRules?.isEmpty == false ? .futureEvents : .thisEvent, commit: true)
      }

      toDo.calendarEventIdentifier = nil
   }

   private func calendarNotes(for toDo: ToDo) -> String? {
      let notes = toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines)
      var sections: [String] = []

      if !notes.isEmpty {
         sections.append(notes)
      }

      let nanoDoLines = toDo.nanoDos
         .sorted { $0.createdAt < $1.createdAt }
         .map { nanoDo in
            let state = nanoDo.isDone ? "Done" : "Open"
            return "- [\(state)] \(nanoDo.task)"
         }

      if !nanoDoLines.isEmpty {
         sections.append("NanoDos:\n\(nanoDoLines.joined(separator: "\n"))")
      }

      if recurrenceRules(for: toDo) == nil, let recurrence = toDo.recurrenceSummary {
         sections.append(recurrence)
      }

      if sections.isEmpty {
         return "Created by toDō."
      }

      return sections.joined(separator: "\n\n")
   }

   private func recurrenceRules(for toDo: ToDo) -> [EKRecurrenceRule]? {
      guard toDo.isRecurring,
            let unit = toDo.recurrenceUnit,
            let interval = toDo.recurrenceInterval,
            interval > 0,
            let mode = toDo.recurrenceMode
      else {
         return nil
      }

      let frequency: EKRecurrenceFrequency
      switch unit {
      case .days:
         frequency = .daily
      case .weeks:
         frequency = .weekly
      case .months:
         frequency = .monthly
      case .years:
         frequency = .yearly
      case .seconds, .minutes, .hours:
         return nil
      }

      let end: EKRecurrenceEnd?
      switch mode {
      case .continuous:
         end = nil
      case .finite:
         end = EKRecurrenceEnd(occurrenceCount: max((toDo.recurrenceCount ?? 1) + 1, 1))
      }

      return [EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: end)]
   }
}
