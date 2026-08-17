// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

/// 存储值与 Android Room Entities / Capacitor SQLite schema 完全一致。
@Model
final class LogEntity {
    @Attribute(.unique) var id: String
    var content: String
    var colorTag: String
    var category: String
    var importance: Int
    var createdAt: String
    var recordDate: String

    init(id: String, content: String, colorTag: String, category: String,
         importance: Int, createdAt: String, recordDate: String) {
        self.id = id
        self.content = content
        self.colorTag = colorTag
        self.category = category
        self.importance = importance
        self.createdAt = createdAt
        self.recordDate = recordDate
    }

    func toModel() -> LogItem {
        LogItem(
            id: id,
            content: content,
            colorTag: ColorTag(rawValue: colorTag) ?? .daily,
            category: Category(rawValue: category) ?? .log,
            importance: importance,
            createdAt: createdAt,
            recordDate: recordDate
        )
    }

    func apply(_ model: LogItem) {
        content = model.content
        colorTag = model.colorTag.rawValue
        category = model.category.rawValue
        importance = model.importance
        createdAt = model.createdAt
        recordDate = model.recordDate
    }
}

@Model
final class EmotionEntity {
    @Attribute(.unique) var id: String
    var level: Int
    var subEmotion: String?
    var status: String?
    var note: String?
    var recordDate: String
    var createdAt: String

    init(id: String, level: Int, subEmotion: String?, status: String?,
         note: String?, recordDate: String, createdAt: String) {
        self.id = id
        self.level = level
        self.subEmotion = subEmotion
        self.status = status
        self.note = note
        self.recordDate = recordDate
        self.createdAt = createdAt
    }

    func toModel() -> EmotionRecord {
        EmotionRecord(
            id: id,
            level: EmotionLevel(rawValue: level) ?? .neutral,
            subEmotion: subEmotion.flatMap(SubEmotion.init(rawValue:)),
            status: status,
            note: note,
            recordDate: recordDate,
            createdAt: createdAt
        )
    }

    func apply(_ model: EmotionRecord) {
        level = model.level.rawValue
        subEmotion = model.subEmotion?.rawValue
        status = model.status
        note = model.note
        recordDate = model.recordDate
        createdAt = model.createdAt
    }
}
