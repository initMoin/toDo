//
//  RemoteNotificationType.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation

enum RemoteNotificationType: String, Codable {
    case toDoDue
    case toDoOverdue
    case recurringToDo
    case circleInvite
    case circleUpdate
    case syncConflict
    case syncCompleted
    case reminder
    case test
}


