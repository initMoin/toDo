//
//  Tag.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 2/9/26.
//

import Foundation
import SwiftData

@Model
final class Tag {
    var cloudID: UUID? = nil
    var ownerUserID: UUID? = nil
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date? = nil

    var toDos: [ToDo]? = nil
    var nanoDos: [NanoDo]? = nil
    var primaryToDos: [ToDo]? = nil

    init(
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        toDos: [ToDo] = [],
        nanoDos: [NanoDo] = [],
        cloudID: UUID? = nil,
        ownerUserID: UUID? = nil
    ) {
        self.cloudID = cloudID
        self.ownerUserID = ownerUserID
        self.name = Self.normalizeName(name)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.toDos = toDos
        self.nanoDos = nanoDos
    }

    var displayName: String {
        Self.normalizeName(name)
    }

    var allToDos: [ToDo] {
        get { toDos ?? [] }
        set { toDos = newValue }
    }

    var allNanoDos: [NanoDo] {
        get { nanoDos ?? [] }
        set { nanoDos = newValue }
    }

    static func normalizeName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var syncUpdatedAt: Date {
        updatedAt ?? createdAt
    }

    func markUpdated(_ date: Date = .now) {
        updatedAt = date
    }
}
