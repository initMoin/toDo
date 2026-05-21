//
//  NavigationCoordinator.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 5/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class NavigationCoordinator {
    enum ListRoute: Equatable {
        case all
        case today
        case overdue
        case due
        case timeSensitive
    }

    static let shared = NavigationCoordinator()

    var notificationRoute: NotificationRoute = .none
    var listRoute: ListRoute?
    var shouldOpenSettings = false

    private init() {}

    func route(url: URL) -> Bool {
        guard url.scheme?.caseInsensitiveCompare("todo") == .orderedSame else {
            return false
        }

        let routeName = url.host?.lowercased()
        let pathComponents = Array(url.pathComponents.dropFirst())
        let pathRouteName = pathComponents.first?.lowercased()
        guard routeName == "todo" || pathRouteName == "todo" else {
            return false
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        let queryItems = components.queryItems ?? []
        let pathIdentifier: String? = {
            if routeName == "todo" {
                return pathComponents.first?.removingPercentEncoding
            }
            guard pathRouteName == "todo", pathComponents.count > 1 else {
                return nil
            }
            return pathComponents[1].removingPercentEncoding
        }()

        let localIdentifier = queryItems.first(where: { $0.name == "localIdentifier" })?.value ?? pathIdentifier
        let cloudID = queryItems
            .first(where: { $0.name == "cloudID" })?
            .value
            .flatMap(UUID.init(uuidString:)) ?? pathIdentifier.flatMap(UUID.init(uuidString:))

        guard localIdentifier != nil || cloudID != nil else {
            return false
        }

        notificationRoute = .toDo(localIdentifier: localIdentifier, cloudID: cloudID)
        return true
    }
}
