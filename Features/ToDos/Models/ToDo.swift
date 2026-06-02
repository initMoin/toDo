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

@Model
final class ToDo {
   #Index<ToDo>([\.ownerUserID])

   static let maxTagSelection = 5

   var cloudID: UUID? = nil
   var ownerUserID: UUID? = nil
   var task: String = ""
   var notes: String = ""
   var createdAt: Date = Date()
   var updatedAt: Date? = nil
   var lastSyncedUpdatedAt: Date? = nil
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
      nanoDos: [NanoDo] = [],
      tag: Tag? = nil,
      tags: [Tag] = [],
      cloudID: UUID? = nil,
      ownerUserID: UUID? = nil
   ) {
      let resolvedState = lifecycleState ?? (isDone ? .done : .active)
      self.cloudID = cloudID
      self.ownerUserID = ownerUserID
      self.task = task
      self.notes = notes
      self.createdAt = createdAt
      self.updatedAt = updatedAt ?? createdAt
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
         lifecycleStateRaw = newValue.rawValue
         isDone = newValue == .done
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
      var resolved: [Tag] = []

      for item in tags {
         guard seen.insert(item.id).inserted else { continue }
         resolved.append(item)
         if resolved.count == Self.maxTagSelection { return resolved }
      }

      if let legacyTag = primaryTag, seen.insert(legacyTag.id).inserted {
         resolved.append(legacyTag)
      }

      return Array(resolved.prefix(Self.maxTagSelection))
   }

   func setSelectedTags(_ newTags: [Tag]) {
      var seen = Set<PersistentIdentifier>()
      var normalized: [Tag] = []

      for item in newTags {
         guard seen.insert(item.id).inserted else { continue }
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
