// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

/// 存储值与 Android Room Entities / Capacitor SQLite schema 完全一致。
///
/// 版本历史：
/// - V1：flash-backup-v2 分区 schema 1 对应的实体形状（冻结，仅用于迁移）。
/// - V2：新增可选字段——日志/情绪/任务 `isFavorite`，情绪 `intensity`，任务 `sourceLogId`
///       （对应备份分区 schema 2，见 app/docs/contracts/README.md）。
/// 视图与仓储经 typealias 引用当前版本实体，升级时只需改别名指向。

enum FlashSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LogEntity.self, EmotionEntity.self, TaskEntity.self]
    }

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
    }

    @Model
    final class TaskEntity {
        @Attribute(.unique) var id: String
        var title: String
        var notes: String?
        var colorTag: String
        var importance: Int
        var dueKind: String
        var dueDate: String?
        var dueAt: String?
        var timeZone: String?
        var reminderAt: String?
        var completedAt: String?
        var createdAt: String
        var updatedAt: String

        init(id: String, title: String, notes: String?, colorTag: String, importance: Int,
             dueKind: String, dueDate: String?, dueAt: String?, timeZone: String?,
             reminderAt: String?, completedAt: String?, createdAt: String, updatedAt: String) {
            self.id = id
            self.title = title
            self.notes = notes
            self.colorTag = colorTag
            self.importance = importance
            self.dueKind = dueKind
            self.dueDate = dueDate
            self.dueAt = dueAt
            self.timeZone = timeZone
            self.reminderAt = reminderAt
            self.completedAt = completedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

enum FlashSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LogEntity.self, EmotionEntity.self, TaskEntity.self]
    }

    @Model
    final class LogEntity {
        @Attribute(.unique) var id: String
        var content: String
        var colorTag: String
        var category: String
        var importance: Int
        /// 收藏（分区 schema 2 新增，可空；缺省视为未收藏）
        var isFavorite: Bool?
        var createdAt: String
        var recordDate: String

        init(id: String, content: String, colorTag: String, category: String,
             importance: Int, isFavorite: Bool? = nil, createdAt: String, recordDate: String) {
            self.id = id
            self.content = content
            self.colorTag = colorTag
            self.category = category
            self.importance = importance
            self.isFavorite = isFavorite
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
                isFavorite: isFavorite,
                createdAt: createdAt,
                recordDate: recordDate
            )
        }

        func apply(_ model: LogItem) {
            content = model.content
            colorTag = model.colorTag.rawValue
            category = model.category.rawValue
            importance = model.importance
            isFavorite = model.isFavorite
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
        /// 情绪强度 1–5（分区 schema 2 新增，可空）
        var intensity: Int?
        /// 收藏（分区 schema 2 新增，可空）
        var isFavorite: Bool?
        var recordDate: String
        var createdAt: String

        init(id: String, level: Int, subEmotion: String?, status: String?,
             note: String?, intensity: Int? = nil, isFavorite: Bool? = nil,
             recordDate: String, createdAt: String) {
            self.id = id
            self.level = level
            self.subEmotion = subEmotion
            self.status = status
            self.note = note
            self.intensity = intensity
            self.isFavorite = isFavorite
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
                intensity: intensity,
                isFavorite: isFavorite,
                recordDate: recordDate,
                createdAt: createdAt
            )
        }

        func apply(_ model: EmotionRecord) {
            level = model.level.rawValue
            subEmotion = model.subEmotion?.rawValue
            status = model.status
            note = model.note
            intensity = model.intensity
            isFavorite = model.isFavorite
            recordDate = model.recordDate
            createdAt = model.createdAt
        }
    }

    @Model
    final class TaskEntity {
        @Attribute(.unique) var id: String
        var title: String
        var notes: String?
        var colorTag: String
        var importance: Int
        var dueKind: String
        var dueDate: String?
        var dueAt: String?
        var timeZone: String?
        var reminderAt: String?
        var completedAt: String?
        /// Idea→Task 来源关联：指向 logs 分区的一条记录 ID（分区 schema 2 新增，可空）
        var sourceLogId: String?
        /// 收藏（分区 schema 2 新增，可空）
        var isFavorite: Bool?
        var createdAt: String
        var updatedAt: String

        init(_ model: TaskItem) {
            id = model.id
            title = model.title
            notes = model.notes
            colorTag = model.colorTag.rawValue
            importance = model.importance
            dueKind = model.dueKind.rawValue
            dueDate = model.dueDate
            dueAt = model.dueAt
            timeZone = model.timeZone
            reminderAt = model.reminderAt
            completedAt = model.completedAt
            sourceLogId = model.sourceLogId
            isFavorite = model.isFavorite
            createdAt = model.createdAt
            updatedAt = model.updatedAt
        }

        func toModel() -> TaskItem {
            TaskItem(
                id: id,
                title: title,
                notes: notes,
                colorTag: ColorTag(rawValue: colorTag) ?? .memo,
                importance: importance,
                dueKind: TaskDueKind(rawValue: dueKind) ?? .allDay,
                dueDate: dueDate,
                dueAt: dueAt,
                timeZone: timeZone,
                reminderAt: reminderAt,
                completedAt: completedAt,
                sourceLogId: sourceLogId,
                isFavorite: isFavorite,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        func apply(_ model: TaskItem) {
            title = model.title
            notes = model.notes
            colorTag = model.colorTag.rawValue
            importance = model.importance
            dueKind = model.dueKind.rawValue
            dueDate = model.dueDate
            dueAt = model.dueAt
            timeZone = model.timeZone
            reminderAt = model.reminderAt
            completedAt = model.completedAt
            sourceLogId = model.sourceLogId
            isFavorite = model.isFavorite
            createdAt = model.createdAt
            updatedAt = model.updatedAt
        }
    }
}

/// 当前生效实体别名：视图与仓储代码不随版本升级改名
typealias LogEntity = FlashSchemaV2.LogEntity
typealias EmotionEntity = FlashSchemaV2.EmotionEntity
typealias TaskEntity = FlashSchemaV2.TaskEntity

/// V1→V2 轻量迁移：纯增列（可选属性），无数据变换
enum FlashMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FlashSchemaV1.self, FlashSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: FlashSchemaV1.self, toVersion: FlashSchemaV2.self)]
    }
}
