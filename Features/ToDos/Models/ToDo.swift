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
            return "Quiet"
        case .due:
            return "Due"
        case .timeSensitive:
            return "Time-Sensitive"
        }
    }

    nonisolated var supportingCopy: String {
        switch self {
        case .soft:
            return "Places the ToDo in Notification Center quietly."
        case .due:
            return "Alerts that the ToDo has reached its due moment."
        case .timeSensitive:
            return "Breaks through Focus when the ToDo needs immediate attention."
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
            return "Seconds"
        case .minutes:
            return "Minutes"
        case .hours:
            return "Hours"
        case .days:
            return "Days"
        case .weeks:
            return "Weeks"
        case .months:
            return "Months"
        case .years:
            return "Years"
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
        let base: String
        switch self {
        case .seconds:
            base = value == 1 ? "second" : "seconds"
        case .minutes:
            base = value == 1 ? "minute" : "minutes"
        case .hours:
            base = value == 1 ? "hour" : "hours"
        case .days:
            base = value == 1 ? "day" : "days"
        case .weeks:
            base = value == 1 ? "week" : "weeks"
        case .months:
            base = value == 1 ? "month" : "months"
        case .years:
            base = value == 1 ? "year" : "years"
        }
        return "\(value) \(base)"
    }
}

enum ToDoRecurrenceMode: String, CaseIterable, Identifiable, Codable {
    case finite
    case continuous

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .finite:
            return "Fixed Count"
        case .continuous:
            return "Continuous"
        }
    }
}

@Model
final class ToDo {
    static let maxTagSelection = 5

    var cloudID: UUID? = nil
    var ownerUserID: UUID? = nil
    var task: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date? = nil
    var lastSyncedUpdatedAt: Date? = nil
    var dueDate: Date? = nil
    var reminderIntentRaw: String = ToDoReminderIntent.soft.rawValue
    var recurrenceUnitRaw: String? = nil
    var recurrenceIntervalValue: Int? = nil
    var recurrenceModeRaw: String? = nil
    var recurrenceCountValue: Int? = nil
    var recurrenceAnchorDate: Date? = nil
    var recurrenceEndDate: Date? = nil
    var lifecycleStateRaw: String = ToDoState.active.rawValue
    var isDone: Bool = false

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
