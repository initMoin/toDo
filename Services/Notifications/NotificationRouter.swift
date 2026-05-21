//
//  NotificationRouter.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import UserNotifications

final class NotificationRouter {

    static let shared = NotificationRouter()

    @MainActor
    func route(notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard let payload = Self.payload(
            from: userInfo,
            title: notification.request.content.title,
            body: notification.request.content.body
        ) else { return }

        route(payload: payload)
    }

    @MainActor
    func route(payload: NotificationPayload) {
        switch payload.type {
        case .toDoDue, .toDoOverdue, .recurringToDo, .reminder:
            guard payload.toDoLocalIdentifier != nil || payload.toDoID != nil else { return }
            NavigationCoordinator.shared.notificationRoute = .toDo(
                localIdentifier: payload.toDoLocalIdentifier,
                cloudID: payload.toDoID
            )

        case .circleInvite, .circleUpdate:
            guard let circleID = payload.circleID else { return }
            NavigationCoordinator.shared.notificationRoute = .circle(circleID)

        case .syncConflict, .syncCompleted:
            NavigationCoordinator.shared.notificationRoute = .sync

        case .test:
            break
        }
    }

    nonisolated static func payload(
        from userInfo: [AnyHashable: Any],
        title: String = "",
        body: String = ""
    ) -> NotificationPayload? {
        guard let typeRaw = userInfo["type"] as? String,
              let type = RemoteNotificationType(rawValue: typeRaw) else { return nil }

        return NotificationPayload(
            type: type,
            title: title,
            body: body,
            toDoID: uuidValue(
                from: userInfo["todoCloudIdentifier"]
            ),
            toDoLocalIdentifier: stringValue(from: userInfo["todoIdentifier"]),
            circleID: uuidValue(from: userInfo["circleID"]),
            isRecurring: userInfo["isRecurring"] as? Bool ?? false,
            isTimeSensitive: userInfo["isTimeSensitive"] as? Bool ?? false
        )
    }

    private nonisolated static func uuidValue(from rawValue: Any?) -> UUID? {
        if let uuid = rawValue as? UUID {
            return uuid
        }

        guard let string = rawValue as? String else {
            return nil
        }

        return UUID(uuidString: string)
    }

    private nonisolated static func stringValue(from rawValue: Any?) -> String? {
        if let uuid = rawValue as? UUID {
            return uuid.uuidString
        }

        guard let string = rawValue as? String,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return string
    }
}
