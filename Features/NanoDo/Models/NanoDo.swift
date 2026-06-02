//
//  NanoDo.swift
//  ToDo
//
//  Created by Moinuddin Ahmad on 2/9/26.
//

import Foundation
import SwiftData

@Model
final class NanoDo {
    #Index<NanoDo>([\.ownerUserID])

    var cloudID: UUID? = nil
    var ownerUserID: UUID? = nil
    var task: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date? = nil
    var dueDate: Date? = nil
    var isDone: Bool = false

    var toDo: ToDo? = nil
    @Relationship(inverse: \Tag.nanoDos)
    var tag: Tag? = nil

    init(
        task: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        dueDate: Date? = nil,
        isDone: Bool = false,
        toDo: ToDo? = nil,
        tag: Tag? = nil,
        cloudID: UUID? = nil,
        ownerUserID: UUID? = nil
    ) {
        self.cloudID = cloudID
        self.ownerUserID = ownerUserID
        self.task = task
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.dueDate = dueDate
        self.isDone = isDone
        self.toDo = toDo
        self.tag = tag
    }

    var syncUpdatedAt: Date {
        updatedAt ?? createdAt
    }

    func markUpdated(_ date: Date = .now) {
        updatedAt = date
    }
}
