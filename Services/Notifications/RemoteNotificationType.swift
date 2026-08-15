//
//  RemoteNotificationType.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation

enum RemoteNotificationType: String, Codable, Sendable {
    case toDoDue
    case toDoOverdue
    case recurringToDo
    case collabInvite
    case collabUpdate
    case syncConflict
    case syncCompleted
    case reminder
    case test

    nonisolated init?(rawValue: String) {
        switch rawValue {
        case "collabInvite", "circleInvite":
            self = .collabInvite
        case "collabUpdate", "circleUpdate":
            self = .collabUpdate
        case "toDoDue":
            self = .toDoDue
        case "toDoOverdue":
            self = .toDoOverdue
        case "recurringToDo":
            self = .recurringToDo
        case "syncConflict":
            self = .syncConflict
        case "syncCompleted":
            self = .syncCompleted
        case "reminder":
            self = .reminder
        case "test":
            self = .test
        default:
            return nil
        }
    }
}
