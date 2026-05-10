//
//  NavigationCoordinator.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import Observation

@Observable
final class NavigationCoordinator {

    static let shared = NavigationCoordinator()

    var notificationRoute: NotificationRoute = .none

    private init() {}
}
