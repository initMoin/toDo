@preconcurrency import ActivityKit
import Foundation
import SwiftData

@MainActor
final class LiveActivityService {
   static let shared = LiveActivityService()

   private var scheduledEndTasks: [String: Task<Void, Never>] = [:]

   private init() {}

   func refresh(from context: ModelContext, preferredToDo: ToDo? = nil) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
         endAllActivities()
         return
      }

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         refresh(using: toDos, preferredToDo: preferredToDo)
      } catch {
         AppLog.error("Failed to refresh ToDo Live Activity: \(error)", logger: AppLog.liveActivity)
      }
   }

   func refresh(from container: ModelContainer) {
      refresh(from: ModelContext(container))
   }

   func endActivity(for toDo: ToDo) {
      let identifier = Self.identifier(for: toDo)
      for activity in Activity<ToDoLiveActivityAttributes>.activities where activity.attributes.toDoIdentifier == identifier {
         end(activity)
      }
   }

   private func refresh(using toDos: [ToDo], preferredToDo: ToDo?) {
      let validCandidates = liveActivityCandidates(from: toDos)
      let activities = Activity<ToDoLiveActivityAttributes>.activities
      let currentIdentifier = activities.first?.attributes.toDoIdentifier

      guard let candidate = liveActivityCandidate(
         from: validCandidates,
         preferredIdentifier: preferredToDo.flatMap(Self.identifierIfLiveActivityEligible(for:)),
         currentIdentifier: currentIdentifier
      ) else {
         endAllActivities()
         return
      }

      let identifier = Self.identifier(for: candidate)
      let content = Self.contentState(for: candidate)
      let matchingActivity = activities.first { $0.attributes.toDoIdentifier == identifier }

      for activity in activities where activity.attributes.toDoIdentifier != identifier {
         end(activity)
      }

      if let matchingActivity {
         update(matchingActivity, with: content)
      } else {
         startActivity(for: candidate, identifier: identifier, content: content)
      }
      scheduleEnd(for: identifier, dueDate: candidate.dueDate)
   }

   private func liveActivityCandidate(
      from candidates: [ToDo],
      preferredIdentifier: String?,
      currentIdentifier: String?
   ) -> ToDo? {
      if let preferredIdentifier,
         let preferredToDo = candidates.first(where: { Self.identifier(for: $0) == preferredIdentifier }) {
         return preferredToDo
      }

      if let currentIdentifier,
         let currentToDo = candidates.first(where: { Self.identifier(for: $0) == currentIdentifier }) {
         return currentToDo
      }

      return candidates.first
   }

   private func liveActivityCandidates(from toDos: [ToDo]) -> [ToDo] {
      let now = Date()
      return toDos
         .filter(Self.isLiveActivityEligible(_:))
         .sorted { lhs, rhs in
            let lhsDueDate = lhs.dueDate ?? .distantFuture
            let rhsDueDate = rhs.dueDate ?? .distantFuture
            let lhsIsUpcoming = lhsDueDate >= now
            let rhsIsUpcoming = rhsDueDate >= now

            if lhsIsUpcoming != rhsIsUpcoming {
               return lhsIsUpcoming
            }

            if lhsIsUpcoming, lhsDueDate != rhsDueDate {
               return lhsDueDate < rhsDueDate
            }

            if !lhsIsUpcoming, lhsDueDate != rhsDueDate {
               return lhsDueDate > rhsDueDate
            }

            return lhs.syncUpdatedAt > rhs.syncUpdatedAt
         }
   }

   private static func isLiveActivityEligible(_ toDo: ToDo) -> Bool {
      guard let dueDate = toDo.dueDate else { return false }
      return toDo.lifecycleState == .active
         && toDo.reminderIntent == .timeSensitive
         && dueDate > .now
   }

   private static func identifierIfLiveActivityEligible(for toDo: ToDo) -> String? {
      guard isLiveActivityEligible(toDo) else { return nil }
      return identifier(for: toDo)
   }

   private func startActivity(
      for toDo: ToDo,
      identifier: String,
      content: ToDoLiveActivityAttributes.ContentState
   ) {
      let attributes = ToDoLiveActivityAttributes(
         toDoIdentifier: identifier,
         toDoLocalIdentifier: Self.localIdentifier(for: toDo),
         toDoCloudIdentifier: toDo.cloudID?.uuidString,
         createdAt: .now
      )

      do {
         let activityContent = ActivityContent(
            state: content,
            staleDate: staleDate(for: toDo),
            relevanceScore: relevanceScore(for: toDo)
         )

         _ = try Activity.request(
            attributes: attributes,
            content: activityContent,
            pushType: nil
         )
      } catch {
         AppLog.error("Failed to start ToDo Live Activity: \(error)", logger: AppLog.liveActivity)
      }
   }

   private func update(
      _ activity: Activity<ToDoLiveActivityAttributes>,
      with content: ToDoLiveActivityAttributes.ContentState
   ) {
      Task {
         await activity.update(ActivityContent(
            state: content,
            staleDate: staleDate(for: content),
            relevanceScore: content.isOverdue ? 1 : 0.85
         ))
      }
   }

   private func endAllActivities() {
      for activity in Activity<ToDoLiveActivityAttributes>.activities {
         end(activity)
      }
      scheduledEndTasks.values.forEach { $0.cancel() }
      scheduledEndTasks.removeAll()
   }

   private func end(_ activity: Activity<ToDoLiveActivityAttributes>) {
      scheduledEndTasks[activity.attributes.toDoIdentifier]?.cancel()
      scheduledEndTasks[activity.attributes.toDoIdentifier] = nil
      Task {
         await activity.end(nil, dismissalPolicy: .immediate)
      }
   }

   private func staleDate(for toDo: ToDo) -> Date? {
      toDo.dueDate
   }

   private func staleDate(for content: ToDoLiveActivityAttributes.ContentState) -> Date? {
      content.dueDate
   }

   private func scheduleEnd(for identifier: String, dueDate: Date?) {
      scheduledEndTasks[identifier]?.cancel()
      guard let dueDate, dueDate > .now else { return }

      scheduledEndTasks[identifier] = Task { [weak self] in
         let delay = max(dueDate.timeIntervalSinceNow, 0)
         do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
         } catch {
            return
         }
         await MainActor.run {
            guard let self else { return }
            for activity in Activity<ToDoLiveActivityAttributes>.activities where activity.attributes.toDoIdentifier == identifier {
               self.end(activity)
            }
         }
      }
   }

   private func relevanceScore(for toDo: ToDo) -> Double {
      guard let dueDate = toDo.dueDate else { return 0.5 }
      return dueDate < .now ? 1 : 0.85
   }

   private static func identifier(for toDo: ToDo) -> String {
      if let cloudID = toDo.cloudID {
         return cloudID.uuidString
      }
      return localIdentifier(for: toDo)
   }

   private static func localIdentifier(for toDo: ToDo) -> String {
      return String(describing: toDo.id)
   }

   private static func contentState(for toDo: ToDo) -> ToDoLiveActivityAttributes.ContentState {
      let now = Date()
      let dueDate = toDo.dueDate
      return ToDoLiveActivityAttributes.ContentState(
         title: toDo.task.isEmpty ? "Untitled ToDo" : toDo.task,
         dueDate: dueDate,
         isOverdue: dueDate.map { $0 < now } ?? false,
         isTimeSensitive: toDo.reminderIntent == .timeSensitive,
         updatedAt: toDo.syncUpdatedAt
      )
   }
}
