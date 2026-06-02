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

      try eventStore.save(event, span: .thisEvent, commit: true)
      toDo.calendarEventIdentifier = event.eventIdentifier
      return event.eventIdentifier
   }

   func removeCalendarEvent(for toDo: ToDo) throws {
      guard let eventIdentifier = toDo.calendarEventIdentifier else { return }

      if let event = eventStore.event(withIdentifier: eventIdentifier) {
         try eventStore.remove(event, span: .thisEvent, commit: true)
      }

      toDo.calendarEventIdentifier = nil
   }

   private func calendarNotes(for toDo: ToDo) -> String? {
      let notes = toDo.notes.trimmingCharacters(in: .whitespacesAndNewlines)
      let recurrence = toDo.recurrenceSummary

      switch (notes.isEmpty, recurrence) {
      case (true, nil):
         return "Created by toDō."
      case (false, nil):
         return notes
      case (true, .some(let recurrence)):
         return "Created by toDō. \(recurrence)."
      case (false, .some(let recurrence)):
         return "\(notes)\n\n\(recurrence)."
      }
   }
}
