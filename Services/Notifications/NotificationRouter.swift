//
//  NotificationRouter.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationRouter {

    static let shared = NotificationRouter()

    func route(notification: UNNotification) {

        let userInfo = notification.request.content.userInfo

        guard let typeRaw = userInfo["type"] as? String,
              let type = RemoteNotificationType(rawValue: typeRaw)
        else {
            return
        }

        switch type {

        case .toDoDue:
            break

        case .circleInvite:
            break

        case .circleUpdate:
            break

        default:
            break
        }
    }
}
