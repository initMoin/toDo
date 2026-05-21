//
//  NotificationPayload.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation

struct NotificationPayload: Codable, Sendable {

    let schemaVersion: Int

    let type: RemoteNotificationType

    let title: String
    let body: String

    let toDoID: UUID?
    let toDoLocalIdentifier: String?
    let circleID: UUID?

    let isRecurring: Bool
    let isTimeSensitive: Bool

    let createdAt: Date

    nonisolated init(
        schemaVersion: Int = 1,
        type: RemoteNotificationType,
        title: String,
        body: String,
        toDoID: UUID? = nil,
        toDoLocalIdentifier: String? = nil,
        circleID: UUID? = nil,
        isRecurring: Bool = false,
        isTimeSensitive: Bool = false,
        createdAt: Date = .now
    ) {
        self.schemaVersion = schemaVersion
        self.type = type
        self.title = title
        self.body = body
        self.toDoID = toDoID
        self.toDoLocalIdentifier = toDoLocalIdentifier
        self.circleID = circleID
        self.isRecurring = isRecurring
        self.isTimeSensitive = isTimeSensitive
        self.createdAt = createdAt
    }
}
