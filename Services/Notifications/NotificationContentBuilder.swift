//
//  NotificationContentBuilder.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import UserNotifications

enum NotificationDebugScenario: String, CaseIterable, Identifiable, Sendable {
   case dueSoon
   case overdue
   case recurring
   case quiet
   case timeSensitive
   case syncRefresh

   var id: String { rawValue }

   var title: String {
      switch self {
      case .dueSoon:
         return String(localized: "Due Reminder")
      case .overdue:
         return String(localized: "Overdue")
      case .recurring:
         return String(localized: "Recurring")
      case .quiet:
         return String(localized: "Quiet")
      case .timeSensitive:
         return String(localized: "Time-Sensitive")
      case .syncRefresh:
         return String(localized: "Sync Refresh")
      }
   }

   var body: String {
      switch self {
      case .dueSoon:
         return String(localized: "Tests the normal due-reminder notification path.")
      case .overdue:
         return String(localized: "Tests urgent overdue reminder copy and metadata.")
      case .recurring:
         return String(localized: "Tests recurring reminder copy and metadata.")
      case .quiet:
         return String(localized: "Tests a passive notification that should avoid sound.")
      case .timeSensitive:
         return String(localized: "Tests a Time Sensitive reminder.")
      case .syncRefresh:
         return String(localized: "Checks whether changes from another device can wake toDō.")
      }
   }

   var notificationType: RemoteNotificationType {
      switch self {
      case .dueSoon, .timeSensitive:
         return .toDoDue
      case .overdue:
         return .toDoOverdue
      case .recurring:
         return .recurringToDo
      case .quiet:
         return .reminder
      case .syncRefresh:
         return .syncCompleted
      }
   }

   var isRecurring: Bool {
      self == .recurring
   }

   var isTimeSensitive: Bool {
      self == .timeSensitive || self == .overdue
   }
}

struct NotificationContentBuilder {

   static func content(
      for type: RemoteNotificationType,
      title: String,
      body: String,
      isTimeSensitive: Bool = false,
      isQuiet: Bool = false,
      soundOption: AppPreferences.NotificationSoundOption = .defaultSound
   ) -> UNMutableNotificationContent {

      let content = UNMutableNotificationContent()

      content.title = title
      content.body = body
      content.sound = notificationSound(isQuiet: isQuiet, soundOption: soundOption)

      switch type {

      case .toDoDue:
         content.categoryIdentifier = NotificationCategoryID.taskReminder.rawValue
         content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active
         content.threadIdentifier = "todo-reminders"
         content.targetContentIdentifier = "todo-due"
         content.relevanceScore = isTimeSensitive ? 1.0 : 0.75

      case .toDoOverdue:
         content.categoryIdentifier = NotificationCategoryID.taskReminder.rawValue
         content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active
         content.threadIdentifier = "todo-reminders"
         content.targetContentIdentifier = "todo-overdue"
         content.relevanceScore = 1.0

      case .recurringToDo:
         content.categoryIdentifier = NotificationCategoryID.recurringReminder.rawValue
         content.interruptionLevel = isTimeSensitive ? .timeSensitive : .active
         content.threadIdentifier = "todo-recurring"
         content.targetContentIdentifier = "todo-recurring"
         content.relevanceScore = isTimeSensitive ? 0.95 : 0.7

      case .circleInvite:
         content.categoryIdentifier = NotificationCategoryID.collaboration.rawValue
         content.threadIdentifier = "circle-invites"
         content.targetContentIdentifier = "circle-invite"
         content.relevanceScore = 0.8

      case .circleUpdate:
         content.categoryIdentifier = NotificationCategoryID.collaboration.rawValue
         content.threadIdentifier = "circle-updates"
         content.targetContentIdentifier = "circle-update"
         content.relevanceScore = 0.6

      case .syncConflict:
         content.categoryIdentifier = NotificationCategoryID.sync.rawValue
         content.threadIdentifier = "sync-events"
         content.targetContentIdentifier = "sync-conflict"
         content.relevanceScore = 0.85

      case .syncCompleted:
         content.categoryIdentifier = NotificationCategoryID.sync.rawValue
         content.sound = nil
         content.interruptionLevel = .passive
         content.threadIdentifier = "sync-events"
         content.targetContentIdentifier = "sync-complete"
         content.relevanceScore = 0.3

      case .reminder:
         content.interruptionLevel = isQuiet ? .passive : .active
         content.threadIdentifier = "general-reminders"
         content.targetContentIdentifier = "general-reminder"
         content.relevanceScore = isQuiet ? 0.3 : 0.5

      case .test:
         content.threadIdentifier = "debug-notifications"
         content.targetContentIdentifier = "debug-notification"
         content.relevanceScore = 0.1
      }

      return content
   }

   private static func notificationSound(
      isQuiet: Bool,
      soundOption: AppPreferences.NotificationSoundOption
   ) -> UNNotificationSound? {
      guard !isQuiet, soundOption != .silent else { return nil }

      if let bundledSoundName = soundOption.bundledSoundName {
         return UNNotificationSound(named: UNNotificationSoundName(rawValue: bundledSoundName))
      }

      return .default
   }

   static func debugContent(
      for scenario: NotificationDebugScenario,
      toDoTitle: String = String(localized: "Review toDō"),
      toDoIdentifier: String? = nil,
      toDoCloudIdentifier: UUID? = nil
   ) -> UNMutableNotificationContent {
      let title: String
      let body: String

      switch scenario {
      case .dueSoon:
         title = String(localized: "toDō: due")
         body = toDoTitle
      case .overdue:
         title = String(localized: "toDō: overdue")
         body = toDoTitle
      case .recurring:
         title = String(localized: "toDō: repeating")
         body = toDoTitle
      case .quiet:
         title = String(localized: "toDō reminder")
         body = toDoTitle
      case .timeSensitive:
         title = String(localized: "Time-sensitive toDō")
         body = toDoTitle
      case .syncRefresh:
         title = String(localized: "toDō Sync")
         body = String(localized: "Changes are ready on your other devices.")
      }

      let content = content(
         for: scenario.notificationType,
         title: title,
         body: body,
         isTimeSensitive: scenario.isTimeSensitive,
         isQuiet: scenario == .quiet
      )

      var userInfo: [String: Any] = [
         "schemaVersion": 1,
         "type": scenario.notificationType.rawValue,
         "isRecurring": scenario.isRecurring,
         "isTimeSensitive": scenario.isTimeSensitive,
         "debugScenario": scenario.rawValue
      ]

      if let toDoIdentifier {
         userInfo["todoIdentifier"] = toDoIdentifier
      }

      if let toDoCloudIdentifier {
         userInfo["todoCloudIdentifier"] = toDoCloudIdentifier.uuidString
      }

      if scenario == .syncRefresh {
         userInfo["todoSync"] = "refresh"
      }

      content.userInfo = userInfo

      return content
   }
}
