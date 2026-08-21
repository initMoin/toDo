//
//  ToDo.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 2/9/26.
//

import Foundation
import SwiftData

enum ToDoState: String, CaseIterable, Identifiable, Codable {
   case active
   case done
   case archived
   case trashed

   nonisolated var id: String { rawValue }
}

enum ToDoReminderIntent: String, CaseIterable, Identifiable, Codable {
   case soft
   case due
   case timeSensitive

   nonisolated var id: String { rawValue }

   nonisolated var title: String {
      switch self {
      case .soft:
         return String(localized: "Quiet")
      case .due:
         return String(localized: "Due")
      case .timeSensitive:
         return String(localized: "Time-Sensitive")
      }
   }

   nonisolated var supportingCopy: String {
      switch self {
      case .soft:
         return String(localized: "Places the toDō in Notification Center quietly.")
      case .due:
         return String(localized: "Alerts that the toDō has reached its due moment.")
      case .timeSensitive:
         return String(localized: "Breaks through Focus when the toDō needs immediate attention.")
      }
   }
}

enum ToDoRecurrenceUnit: String, CaseIterable, Identifiable, Codable {
   case seconds
   case minutes
   case hours
   case days
   case weeks
   case months
   case years

   nonisolated var id: String { rawValue }

   nonisolated var title: String {
      switch self {
      case .seconds:
         return String(localized: "Seconds")
      case .minutes:
         return String(localized: "Minutes")
      case .hours:
         return String(localized: "Hours")
      case .days:
         return String(localized: "Days")
      case .weeks:
         return String(localized: "Weeks")
      case .months:
         return String(localized: "Months")
      case .years:
         return String(localized: "Years")
      }
   }

   nonisolated var calendarComponent: Calendar.Component {
      switch self {
      case .seconds:
         return .second
      case .minutes:
         return .minute
      case .hours:
         return .hour
      case .days:
         return .day
      case .weeks:
         return .weekOfYear
      case .months:
         return .month
      case .years:
         return .year
      }
   }

   nonisolated func displayLabel(for value: Int) -> String {
      switch self {
      case .seconds:
         return AppLocalization.localizedCount(value, singularKey: "%@ second", pluralKey: "%@ seconds")
      case .minutes:
         return AppLocalization.localizedCount(value, singularKey: "%@ minute", pluralKey: "%@ minutes")
      case .hours:
         return AppLocalization.localizedCount(value, singularKey: "%@ hour", pluralKey: "%@ hours")
      case .days:
         return AppLocalization.localizedCount(value, singularKey: "%@ day", pluralKey: "%@ days")
      case .weeks:
         return AppLocalization.localizedCount(value, singularKey: "%@ week", pluralKey: "%@ weeks")
      case .months:
         return AppLocalization.localizedCount(value, singularKey: "%@ month", pluralKey: "%@ months")
      case .years:
         return AppLocalization.localizedCount(value, singularKey: "%@ year", pluralKey: "%@ years")
      }
   }
}

enum ToDoRecurrenceMode: String, CaseIterable, Identifiable, Codable {
   case finite
   case continuous

   nonisolated var id: String { rawValue }

   nonisolated var title: String {
      switch self {
      case .finite:
         return String(localized: "Fixed Count")
      case .continuous:
         return String(localized: "Continuous")
      }
   }
}

enum ToDoLocationReminderTrigger: String, CaseIterable, Identifiable, Codable {
   case arriving
   case leaving

   nonisolated var id: String { rawValue }

   nonisolated var title: String {
      switch self {
      case .arriving:
         return String(localized: "Arriving")
      case .leaving:
         return String(localized: "Leaving")
      }
   }
}

nonisolated enum ToDoSelectionIdentity: Hashable {
   case cloud(UUID)
   case local(PersistentIdentifier)
}

@Model
final class ToDo {
   #Index<ToDo>([\.ownerUserID], [\.collabID])

   static let maxTagSelection = 5

   var selectionIdentity: ToDoSelectionIdentity {
      cloudID.map(ToDoSelectionIdentity.cloud) ?? .local(persistentModelID)
   }

   static func resolveSelection(
      _ identity: ToDoSelectionIdentity?,
      from candidates: [ToDo],
      excluding excludedStates: Set<ToDoState> = [.trashed]
   ) -> ToDo? {
      guard let identity else { return nil }
      return candidates.first {
         $0.selectionIdentity == identity && !excludedStates.contains($0.lifecycleState)
      }
   }

   /// Returns one presentation record per remote identity while preserving the
   /// input order. Records without a remote identity remain distinct because
   /// they may be separate unsynced toDos with identical content.
   static func canonicalToDos(from toDos: [ToDo]) -> [ToDo] {
      var preferredByCloudID: [UUID: ToDo] = [:]

      for toDo in toDos {
         guard let cloudID = toDo.cloudID else { continue }
         if let existing = preferredByCloudID[cloudID] {
            if shouldPreferForPresentation(toDo, over: existing) {
               preferredByCloudID[cloudID] = toDo
            }
         } else {
            preferredByCloudID[cloudID] = toDo
         }
      }

      var emittedCloudIDs = Set<UUID>()
      return toDos.compactMap { toDo in
         guard let cloudID = toDo.cloudID else { return toDo }
         guard emittedCloudIDs.insert(cloudID).inserted else { return nil }
         return preferredByCloudID[cloudID]
      }
   }

   static func dueSoonUpperBound(
      from now: Date = Date(),
      horizonDays: Int = 3,
      calendar: Calendar = .current
   ) -> Date {
      calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
   }

   static func recent(
      from toDos: [ToDo],
      now: Date = Date(),
      ageInDays: Int = 3,
      calendar: Calendar = .current
   ) -> [ToDo] {
      let cutoff = calendar.date(byAdding: .day, value: -ageInDays, to: now) ?? now
      return active(from: toDos)
         .filter { $0.createdAt >= cutoff }
         .sorted {
            if $0.createdAt != $1.createdAt {
               return $0.createdAt > $1.createdAt
            }
            return $0.syncUpdatedAt > $1.syncUpdatedAt
         }
   }

   static func dueSoon(
      from toDos: [ToDo],
      now: Date = Date(),
      horizonDays: Int = 3,
      calendar: Calendar = .current
   ) -> [ToDo] {
      let upperBound = dueSoonUpperBound(from: now, horizonDays: horizonDays, calendar: calendar)
      return active(from: toDos)
         .filter { toDo in
            guard let dueDate = toDo.dueDate else { return false }
            return dueDate >= now && dueDate <= upperBound
         }
         .sorted { presentationDueDateSort($0, $1, now: now) }
   }

   static func timeSensitive(
      from toDos: [ToDo],
      now: Date = Date()
   ) -> [ToDo] {
      active(from: toDos)
         .filter { $0.reminderIntent == .timeSensitive }
         .sorted { presentationDueDateSort($0, $1, now: now) }
   }

   static func active(from toDos: [ToDo]) -> [ToDo] {
      toDos.filter { $0.lifecycleState == .active }
   }

   static func presentationDueDateSort(
      _ lhs: ToDo,
      _ rhs: ToDo,
      now: Date = Date()
   ) -> Bool {
      let left = lhs.dueDate ?? .distantFuture
      let right = rhs.dueDate ?? .distantFuture
      if left == right {
         let lhsIsLate = lhs.lifecycleState == .active && (lhs.dueDate.map { $0 < now } ?? false)
         let rhsIsLate = rhs.lifecycleState == .active && (rhs.dueDate.map { $0 < now } ?? false)
         if lhsIsLate != rhsIsLate {
            return lhsIsLate && !rhsIsLate
         }
         return lhs.createdAt > rhs.createdAt
      }
      return left < right
   }

   private static func shouldPreferForPresentation(_ lhs: ToDo, over rhs: ToDo) -> Bool {
      if lhs.syncUpdatedAt != rhs.syncUpdatedAt {
         return lhs.syncUpdatedAt > rhs.syncUpdatedAt
      }
      if lhs.lastSyncedUpdatedAt != rhs.lastSyncedUpdatedAt {
         return (lhs.lastSyncedUpdatedAt ?? .distantPast) > (rhs.lastSyncedUpdatedAt ?? .distantPast)
      }
      if lhs.nanoDos.count != rhs.nanoDos.count {
         return lhs.nanoDos.count > rhs.nanoDos.count
      }
      return String(describing: lhs.id) < String(describing: rhs.id)
   }

   var cloudID: UUID? = nil
   var ownerUserID: UUID? = nil
   var collabID: UUID? = nil
   var task: String = ""
   var notes: String = ""
   var createdAt: Date = Date()
   var updatedAt: Date? = nil
   var lastSyncedUpdatedAt: Date? = nil
   /// The most recent transition into the completed state. Older records may not have this value.
   var completedAt: Date? = nil
   var dueDate: Date? = nil
   var calendarEventIdentifier: String? = nil
   var reminderIntentRaw: String = ToDoReminderIntent.soft.rawValue
   var recurrenceUnitRaw: String? = nil
   var recurrenceIntervalValue: Int? = nil
   var recurrenceModeRaw: String? = nil
   var recurrenceCountValue: Int? = nil
   var recurrenceAnchorDate: Date? = nil
   var recurrenceEndDate: Date? = nil
   var locationReminderLatitude: Double? = nil
   var locationReminderLongitude: Double? = nil
   var locationReminderRadius: Double? = nil
   var locationReminderTriggerRaw: String? = nil
   var locationReminderLabel: String? = nil
   var lifecycleStateRaw: String = ToDoState.active.rawValue
   var isDone: Bool = false
   var completeWhenAllNanoDosDone: Bool = false
   var trashedAt: Date?

   @Relationship(deleteRule: .cascade, originalName: "nanoDos", inverse: \NanoDo.toDo)
   var nanoDosStorage: [NanoDo]? = nil
   @Relationship(originalName: "tag", inverse: \Tag.primaryToDos)
   var primaryTag: Tag? = nil
   @Relationship(originalName: "tags", inverse: \Tag.toDos)
   var tagsStorage: [Tag]? = nil

   init(
      task: String,
      notes: String = "",
      createdAt: Date = Date(),
      updatedAt: Date? = nil,
      completedAt: Date? = nil,
      dueDate: Date? = nil,
      reminderIntent: ToDoReminderIntent? = nil,
      recurrenceUnit: ToDoRecurrenceUnit? = nil,
      recurrenceInterval: Int? = nil,
      recurrenceMode: ToDoRecurrenceMode? = nil,
      recurrenceCount: Int? = nil,
      recurrenceAnchorDate: Date? = nil,
      recurrenceEndDate: Date? = nil,
      locationReminderLatitude: Double? = nil,
      locationReminderLongitude: Double? = nil,
      locationReminderRadius: Double? = nil,
      locationReminderTrigger: ToDoLocationReminderTrigger? = nil,
      locationReminderLabel: String? = nil,
      lifecycleState: ToDoState? = nil,
      isDone: Bool = false,
      completeWhenAllNanoDosDone: Bool = false,
      nanoDos: [NanoDo] = [],
      tag: Tag? = nil,
      tags: [Tag] = [],
      cloudID: UUID? = nil,
      ownerUserID: UUID? = nil,
      collabID: UUID? = nil
   ) {
      let resolvedState = lifecycleState ?? (isDone ? .done : .active)
      self.cloudID = cloudID
      self.ownerUserID = ownerUserID
      self.collabID = collabID
      self.task = task
      self.notes = notes
      self.createdAt = createdAt
      self.updatedAt = updatedAt ?? createdAt
      self.completedAt = completedAt ?? (resolvedState == .done ? (updatedAt ?? createdAt) : nil)
      self.dueDate = dueDate
      self.reminderIntentRaw = (reminderIntent ?? (dueDate == nil ? .soft : .due)).rawValue
      self.recurrenceUnitRaw = recurrenceUnit?.rawValue
      self.recurrenceIntervalValue = recurrenceInterval
      self.recurrenceModeRaw = recurrenceMode?.rawValue
      self.recurrenceCountValue = recurrenceCount
      self.recurrenceAnchorDate = recurrenceAnchorDate
      self.recurrenceEndDate = recurrenceEndDate
      self.locationReminderLatitude = locationReminderLatitude
      self.locationReminderLongitude = locationReminderLongitude
      self.locationReminderRadius = locationReminderRadius
      self.locationReminderTriggerRaw = locationReminderTrigger?.rawValue
      self.locationReminderLabel = locationReminderLabel
      self.lifecycleStateRaw = resolvedState.rawValue
      self.isDone = resolvedState == .done
      self.completeWhenAllNanoDosDone = completeWhenAllNanoDosDone
      self.nanoDosStorage = nanoDos
      self.primaryTag = tag
      if tags.isEmpty, let tag {
         self.tagsStorage = [tag]
      } else {
         let normalizedTags = Array(tags.prefix(Self.maxTagSelection))
         self.tagsStorage = normalizedTags
         self.primaryTag = normalizedTags.first
      }
   }

   var nanoDos: [NanoDo] {
      get { nanoDosStorage ?? [] }
      set { nanoDosStorage = newValue }
   }

   /// SwiftData to-many relationships do not preserve insertion order.
   /// Present NanoDos deterministically across devices using their synced creation time.
   var orderedNanoDos: [NanoDo] {
      nanoDos.sorted { lhs, rhs in
         if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
         }

         let lhsKey = lhs.cloudID?.uuidString ?? String(describing: lhs.id)
         let rhsKey = rhs.cloudID?.uuidString ?? String(describing: rhs.id)
         return lhsKey < rhsKey
      }
   }

   @discardableResult
   func completeIfAllNanoDosAreDone() -> Bool {
      guard completeWhenAllNanoDosDone,
            isActive,
            !nanoDos.isEmpty,
            nanoDos.allSatisfy(\.isDone)
      else {
         return false
      }

      transition(to: .done)
      return true
   }

   var tag: Tag? {
      get { primaryTag }
      set { primaryTag = newValue }
   }

   var tags: [Tag] {
      get { tagsStorage ?? [] }
      set {
         tagsStorage = Array(newValue.prefix(Self.maxTagSelection))
         primaryTag = (tagsStorage ?? []).first
         markUpdated()
      }
   }

   var lifecycleState: ToDoState {
      get { ToDoState(rawValue: lifecycleStateRaw) ?? (isDone ? .done : .active) }
      set {
         let previousState = ToDoState(rawValue: lifecycleStateRaw) ?? (isDone ? .done : .active)
         lifecycleStateRaw = newValue.rawValue
         isDone = newValue == .done
         if newValue == .done, previousState != .done {
            completedAt = .now
         } else if newValue != .done {
            completedAt = nil
         }
         markUpdated()
      }
   }

   var isActive: Bool {
      lifecycleState == .active
   }

   var isDoneState: Bool {
      lifecycleState == .done
   }

   var isArchived: Bool {
      lifecycleState == .archived
   }

   var syncUpdatedAt: Date {
      updatedAt ?? createdAt
   }

   /// A stable date for contribution-style completion reporting.
   /// The fallback keeps pre-tracker completed records visible until they are edited.
   var completionActivityDate: Date? {
      guard lifecycleState == .done else { return nil }
      return completedAt ?? syncUpdatedAt
   }

   var isLate: Bool {
      guard lifecycleState == .active, let dueDate else { return false }
      return dueDate < .now
   }

   func matchesFocusFilter(modeRawValue: String) -> Bool {
      switch modeRawValue {
      case "timeSensitiveOnly":
         return reminderIntent == .timeSensitive
      case "dueOnly":
         return dueDate != nil
      default:
         return true
      }
   }

   var reminderIntent: ToDoReminderIntent {
      get { ToDoReminderIntent(rawValue: reminderIntentRaw) ?? (dueDate == nil ? .soft : .due) }
      set { reminderIntentRaw = newValue.rawValue }
   }

   var recurrenceUnit: ToDoRecurrenceUnit? {
      get { recurrenceUnitRaw.flatMap(ToDoRecurrenceUnit.init(rawValue:)) }
      set { recurrenceUnitRaw = newValue?.rawValue }
   }

   var recurrenceInterval: Int? {
      get { recurrenceIntervalValue }
      set { recurrenceIntervalValue = newValue }
   }

   var recurrenceMode: ToDoRecurrenceMode? {
      get { recurrenceModeRaw.flatMap(ToDoRecurrenceMode.init(rawValue:)) }
      set { recurrenceModeRaw = newValue?.rawValue }
   }

   var recurrenceCount: Int? {
      get { recurrenceCountValue }
      set { recurrenceCountValue = newValue }
   }

   var isRecurring: Bool {
      guard dueDate != nil,
            recurrenceUnit != nil,
            let recurrenceMode,
            let recurrenceInterval,
            recurrenceInterval > 0
      else {
         return false
      }

      if recurrenceMode == .finite {
         return (recurrenceCount ?? 0) >= 1
      }

      return recurrenceUnitRaw != nil
   }

   var locationReminderTrigger: ToDoLocationReminderTrigger {
      get {
         locationReminderTriggerRaw.flatMap(ToDoLocationReminderTrigger.init(rawValue:)) ?? .arriving
      }
      set {
         locationReminderTriggerRaw = newValue.rawValue
         markUpdated()
      }
   }

   var hasLocationReminder: Bool {
      locationReminderLatitude != nil && locationReminderLongitude != nil
   }

   var resolvedLocationReminderRadius: Double {
      min(max(locationReminderRadius ?? 150, 100), 1_000)
   }

   func clearLocationReminder() {
      locationReminderLatitude = nil
      locationReminderLongitude = nil
      locationReminderRadius = nil
      locationReminderTriggerRaw = nil
      locationReminderLabel = nil
      markUpdated()
   }

   var recurrenceSummary: String? {
      guard isRecurring,
            let unit = recurrenceUnit,
            let interval = recurrenceInterval,
            let mode = recurrenceMode
      else {
         return nil
      }

      let cadence = "Every \(unit.displayLabel(for: interval))"
      switch mode {
      case .continuous:
         return "\(cadence) continuously"
      case .finite:
         let count = recurrenceCount ?? 1
         let label = count == 1 ? "1 additional time" : "\(count) additional times"
         return "\(cadence) for \(label)"
      }
   }

   var effectiveTags: [Tag] {
      var seen = Set<PersistentIdentifier>()
      var seenNames = Set<String>()
      var resolved: [Tag] = []

      if let primaryTag {
         seen.insert(primaryTag.id)
         seenNames.insert(Tag.normalizeName(primaryTag.name))
         resolved.append(primaryTag)
      }

      // SwiftData to-many relationships are unordered. Keep the explicit
      // primary tag first, then make every remaining tag deterministic.
      let remainingTags = tags.sorted { lhs, rhs in
         let leftName = Tag.normalizeName(lhs.name)
         let rightName = Tag.normalizeName(rhs.name)
         if leftName != rightName {
            return leftName < rightName
         }

         let leftKey = lhs.cloudID?.uuidString ?? String(describing: lhs.id)
         let rightKey = rhs.cloudID?.uuidString ?? String(describing: rhs.id)
         return leftKey < rightKey
      }

      for item in remainingTags {
         guard seen.insert(item.id).inserted else { continue }
         guard seenNames.insert(Tag.normalizeName(item.name)).inserted else { continue }
         resolved.append(item)
         if resolved.count == Self.maxTagSelection { return resolved }
      }

      return Array(resolved.prefix(Self.maxTagSelection))
   }

   func setSelectedTags(_ newTags: [Tag]) {
      var seen = Set<PersistentIdentifier>()
      var seenNames = Set<String>()
      var normalized: [Tag] = []

      for item in newTags {
         guard seen.insert(item.id).inserted else { continue }
         guard seenNames.insert(Tag.normalizeName(item.name)).inserted else { continue }
         normalized.append(item)
         if normalized.count == Self.maxTagSelection { break }
      }

      tags = normalized
      tag = normalized.first
      markUpdated()
   }

   func transition(to state: ToDoState) {
      lifecycleState = state
   }

   func clearRecurrence() {
      recurrenceUnit = nil
      recurrenceInterval = nil
      recurrenceMode = nil
      recurrenceCount = nil
      recurrenceAnchorDate = nil
      recurrenceEndDate = nil
      markUpdated()
   }

   func markUpdated(_ date: Date = .now) {
      updatedAt = date
   }
}

struct ToDoActivityDay: Identifiable, Hashable, Sendable {
   let date: Date
   let completionCount: Int

   var id: Date { date }

   /// Four levels keep the graph readable without making it look like a chart.
   var intensity: Int {
      switch completionCount {
      case 0: return 0
      case 1: return 1
      case 2: return 2
      case 3...4: return 3
      default: return 4
      }
   }
}

enum ToDoActivityTracker {
   /// Builds an aligned week grid in O(toDos + days) time using a date-keyed count map.
   static func grid(
      from toDos: [ToDo],
      endingAt endDate: Date = .now,
      weekCount: Int = 12,
      calendar: Calendar = .current
   ) -> [[ToDoActivityDay]] {
      let safeWeekCount = max(1, weekCount)
      let dayCalendar = calendar
      let today = dayCalendar.startOfDay(for: endDate)
      let currentWeekStart = dayCalendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
      let firstWeekStart = dayCalendar.date(byAdding: .weekOfYear, value: -(safeWeekCount - 1), to: currentWeekStart) ?? currentWeekStart
      let completionCounts = Dictionary(
         grouping: toDos.compactMap(\.completionActivityDate).map { dayCalendar.startOfDay(for: $0) },
         by: { $0 }
      ).mapValues { $0.count }

      return (0..<safeWeekCount).map { weekOffset in
         (0..<7).map { dayOffset in
            let offset = (weekOffset * 7) + dayOffset
            let date = dayCalendar.date(byAdding: .day, value: offset, to: firstWeekStart) ?? firstWeekStart
            return ToDoActivityDay(date: date, completionCount: completionCounts[date, default: 0])
         }
      }
   }
}
