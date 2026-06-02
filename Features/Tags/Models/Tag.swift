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
    #Index<Tag>([\.ownerUserID])

    static let defaultTagNames = ["personal", "work", "health", "shopping", "ideas"]

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
        let normalized = Self.normalizeName(name)
        return Self.defaultTagNames.contains(normalized) ? String(localized: String.LocalizationValue(normalized)) : normalized
    }

    var allToDos: [ToDo] {
        get { toDos ?? [] }
        set { toDos = newValue }
    }

    var allNanoDos: [NanoDo] {
        get { nanoDos ?? [] }
        set { nanoDos = newValue }
    }

   var linkedTaskCount: Int {
      let uniqueToDoIDs = Set(
         (toDos ?? []).map(\.id) +
         (primaryToDos ?? []).map(\.id)
      )
      let nanoDoCount = nanoDos?.count ?? 0

      return uniqueToDoIDs.count + nanoDoCount
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
