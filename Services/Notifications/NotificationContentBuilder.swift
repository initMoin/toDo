//
//  NotificationContentBuilder.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import UserNotifications

struct NotificationContentBuilder {
   
   static func content(
      for type: RemoteNotificationType,
      title: String,
      body: String
   ) -> UNMutableNotificationContent {
      
      let content = UNMutableNotificationContent()
      
      content.title = title
      content.body = body
      
      switch type {
         
      case .toDoDue:
         content.categoryIdentifier =
         NotificationCategoryID.taskReminder.rawValue
         
         content.sound = .default
         
         content.interruptionLevel = .timeSensitive
         
         content.threadIdentifier = "todo-reminders"
         
         content.targetContentIdentifier = "todo-due"
         
         content.relevanceScore = 0.9
         
      case .toDoOverdue:
         content.categoryIdentifier =
         NotificationCategoryID.taskReminder.rawValue
         
         content.sound = .default
         
         content.interruptionLevel = .timeSensitive
         
         content.threadIdentifier = "todo-reminders"
         
         content.targetContentIdentifier = "todo-overdue"
         
         content.relevanceScore = 0.9
         
      case .recurringToDo:
         content.categoryIdentifier =
         NotificationCategoryID.recurringReminder.rawValue
         
         content.sound = .default
         
         content.threadIdentifier = "todo-recurring"
         
         content.targetContentIdentifier = "todo-recurring"
         
         content.relevanceScore = 0.7
         
      case .circleInvite:
         content.categoryIdentifier =
         NotificationCategoryID.collaboration.rawValue
         
         content.sound = .default
         
         content.threadIdentifier = "circle-invites"
         
         content.targetContentIdentifier = "circle-invite"
         
         content.relevanceScore = 0.8
         
      case .circleUpdate:
         content.categoryIdentifier =
         NotificationCategoryID.collaboration.rawValue
         
         content.sound = .default
         
         content.threadIdentifier = "circle-updates"
         
         content.targetContentIdentifier = "circle-update"

         content.relevanceScore = 0.6
         
      case .syncConflict:
         content.categoryIdentifier =
         NotificationCategoryID.sync.rawValue
         
         content.sound = .default
         
         content.threadIdentifier = "sync-events"
         
         content.targetContentIdentifier = "sync-conflict"

         content.relevanceScore = 0.85
         
      case .syncCompleted:
         content.sound = nil
         
         content.threadIdentifier = "sync-events"
         
         content.targetContentIdentifier = "sync-complete"
         
         content.relevanceScore = 0.3
         
      case .reminder:
         content.sound = .default
         
         content.threadIdentifier = "general-reminders"
         
         content.targetContentIdentifier = "general-reminder"

         content.relevanceScore = 0.5
         
      case .test:
         content.sound = .default
         
         content.threadIdentifier = "debug-notifications"
         
         content.targetContentIdentifier = "debug-notification"

         content.relevanceScore = 0.1
      }
      
      return content
   }
}
