//
//  NotificationRoute.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation

enum NotificationRoute: Equatable, Sendable {

    case toDo(localIdentifier: String?, cloudID: UUID?)

    case collab(UUID)

    case sync

    case none
}
