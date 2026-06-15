@preconcurrency import ActivityKit
import Foundation
import SwiftData

@MainActor
final class LiveActivityService {
   static let shared = LiveActivityService()

   private var scheduledEndTasks: [String: Task<Void, Never>] = [:]
   private var pushToStartTokenTask: Task<Void, Never>?
   private var updateTokenTasks: [String: Task<Void, Never>] = [:]

   private init() {}

   func startObservingPushTokens() {
      observePushToStartTokenIfNeeded()
      observeExistingActivityTokens()
   }

   func refresh(from context: ModelContext, preferredToDo: ToDo? = nil) {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else {
         AppLog.info("Live Activity refresh skipped: activities are disabled.", logger: AppLog.liveActivity)
         endAllActivities()
         return
      }

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         refresh(using: toDos, preferredToDo: preferredToDo)
      } catch {
         AppLog.error("Failed to refresh toDō Live Activity: \(error)", logger: AppLog.liveActivity)
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
      let scopedToDos = scopedToDos(toDos)
      let validCandidates = liveActivityCandidates(from: scopedToDos)
      let activities = Activity<ToDoLiveActivityAttributes>.activities
      let currentIdentifier = activities.first?.attributes.toDoIdentifier
      let preferredCandidate = preferredToDo.flatMap { preferredToDo in
         Self.isLiveActivityEligible(preferredToDo) ? preferredToDo : nil
      }

      guard let candidate = liveActivityCandidate(
         from: validCandidates,
         preferredCandidate: preferredCandidate,
         currentIdentifier: currentIdentifier
      ) else {
         AppLog.info("Live Activity refresh ended all activities: candidates=\(toDos.count), scoped=\(scopedToDos.count), eligible=0, preferredEligible=\(preferredCandidate != nil).", logger: AppLog.liveActivity)
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
         AppLog.info("Live Activity updating \(identifier) due \(candidate.dueDate?.description ?? "none").", logger: AppLog.liveActivity)
         update(matchingActivity, with: content)
      } else {
         AppLog.info("Live Activity starting \(identifier) due \(candidate.dueDate?.description ?? "none").", logger: AppLog.liveActivity)
         startActivity(for: candidate, identifier: identifier, content: content)
      }
      scheduleEnd(for: identifier, dueDate: candidate.dueDate)
   }

   private func liveActivityCandidate(
      from candidates: [ToDo],
      preferredCandidate: ToDo?,
      currentIdentifier: String?
   ) -> ToDo? {
      if let preferredCandidate {
         return preferredCandidate
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

   private func scopedToDos(_ toDos: [ToDo]) -> [ToDo] {
      let ownerUserID = SyncCoordinator.shared.effectiveSyncMode == .syncEverywhere
         ? SupabaseAuthStore.shared.scopedOwnerUserID
         : nil

      return toDos.filter { $0.ownerUserID == ownerUserID }
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

         let activity = try Activity.request(
            attributes: attributes,
            content: activityContent,
            pushType: .token
         )
         observeUpdateToken(for: activity)
         AppLog.info("Live Activity start request accepted for \(identifier).", logger: AppLog.liveActivity)
      } catch {
         AppLog.error("Failed to start toDō Live Activity: \(error)", logger: AppLog.liveActivity)
      }
   }

   private func update(
      _ activity: Activity<ToDoLiveActivityAttributes>,
      with content: ToDoLiveActivityAttributes.ContentState
   ) {
      Task { @MainActor in
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
      AppLog.info("Live Activity ending \(activity.attributes.toDoIdentifier).", logger: AppLog.liveActivity)
      let activityID = activity.id
      updateTokenTasks[activityID]?.cancel()
      updateTokenTasks[activityID] = nil
      Task { @MainActor in
         await SupabaseAuthStore.shared.deactivateLiveActivityToken(activityID: activityID)
         await activity.end(nil, dismissalPolicy: .immediate)
      }
   }

   private func observePushToStartTokenIfNeeded() {
      guard pushToStartTokenTask == nil else { return }

      pushToStartTokenTask = Task {
         for await tokenData in Activity<ToDoLiveActivityAttributes>.pushToStartTokenUpdates {
            let token = Self.hexToken(from: tokenData)
            await SupabaseAuthStore.shared.syncLiveActivityToken(
               token: token,
               tokenType: .pushToStart
            )
         }
      }
   }

   private func observeExistingActivityTokens() {
      for activity in Activity<ToDoLiveActivityAttributes>.activities {
         observeUpdateToken(for: activity)
      }
   }

   private func observeUpdateToken(for activity: Activity<ToDoLiveActivityAttributes>) {
      guard updateTokenTasks[activity.id] == nil else { return }

      updateTokenTasks[activity.id] = Task {
         for await tokenData in activity.pushTokenUpdates {
            let token = Self.hexToken(from: tokenData)
            await SupabaseAuthStore.shared.syncLiveActivityToken(
               token: token,
               tokenType: .update,
               activityID: activity.id,
               toDoIdentifier: activity.attributes.toDoIdentifier,
               toDoCloudIdentifier: activity.attributes.toDoCloudIdentifier
            )
         }
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
         title: toDo.task.isEmpty ? "Untitled toDō" : toDo.task,
         dueDate: dueDate,
         isOverdue: dueDate.map { $0 < now } ?? false,
         isTimeSensitive: toDo.reminderIntent == .timeSensitive,
         updatedAt: toDo.syncUpdatedAt
      )
   }

   private static func hexToken(from data: Data) -> String {
      data.map { String(format: "%02x", $0) }.joined()
   }
}
