//
//  NotificationRoute.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation

enum NotificationRoute: Equatable {

    case toDo(UUID)

    case circle(UUID)

    case sync

    case none
}
