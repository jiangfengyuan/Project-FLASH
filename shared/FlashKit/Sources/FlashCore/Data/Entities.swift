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

public enum FlashSchemaV1: VersionedSchema, Sendable {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [LogEntity.self, EmotionEntity.self, TaskEntity.self]
    }

    @Model
    public final class LogEntity {
        @Attribute(.unique) public var id: String
        public var content: String
        public var colorTag: String
        public var category: String
        public var importance: Int
        public var createdAt: String
        public var recordDate: String

        public init(id: String, content: String, colorTag: String, category: String,
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
    public final class EmotionEntity {
        @Attribute(.unique) public var id: String
        public var level: Int
        public var subEmotion: String?
        public var status: String?
        public var note: String?
        public var recordDate: String
        public var createdAt: String

        public init(id: String, level: Int, subEmotion: String?, status: String?,
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
    public final class TaskEntity {
        @Attribute(.unique) public var id: String
        public var title: String
        public var notes: String?
        public var colorTag: String
        public var importance: Int
        public var dueKind: String
        public var dueDate: String?
        public var dueAt: String?
        public var timeZone: String?
        public var reminderAt: String?
        public var completedAt: String?
        public var createdAt: String
        public var updatedAt: String

        public init(id: String, title: String, notes: String?, colorTag: String, importance: Int,
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

public enum FlashSchemaV2: VersionedSchema, Sendable {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [LogEntity.self, EmotionEntity.self, TaskEntity.self]
    }

    @Model
    public final class LogEntity {
        @Attribute(.unique) public var id: String
        public var content: String
        public var colorTag: String
        public var category: String
        public var importance: Int
        /// 收藏（分区 schema 2 新增，可空；缺省视为未收藏）
        public var isFavorite: Bool?
        public var createdAt: String
        public var recordDate: String

        public init(id: String, content: String, colorTag: String, category: String,
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

        public func toModel() -> LogItem {
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

        public func apply(_ model: LogItem) {
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
    public final class EmotionEntity {
        @Attribute(.unique) public var id: String
        public var level: Int
        public var subEmotion: String?
        public var status: String?
        public var note: String?
        /// 情绪强度 1–5（分区 schema 2 新增，可空）
        public var intensity: Int?
        /// 收藏（分区 schema 2 新增，可空）
        public var isFavorite: Bool?
        public var recordDate: String
        public var createdAt: String

        public init(id: String, level: Int, subEmotion: String?, status: String?,
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

        public func toModel() -> EmotionRecord {
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

        public func apply(_ model: EmotionRecord) {
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
    public final class TaskEntity {
        @Attribute(.unique) public var id: String
        public var title: String
        public var notes: String?
        public var colorTag: String
        public var importance: Int
        public var dueKind: String
        public var dueDate: String?
        public var dueAt: String?
        public var timeZone: String?
        public var reminderAt: String?
        public var completedAt: String?
        /// Idea→Task 来源关联：指向 logs 分区的一条记录 ID（分区 schema 2 新增，可空）
        public var sourceLogId: String?
        /// 收藏（分区 schema 2 新增，可空）
        public var isFavorite: Bool?
        public var createdAt: String
        public var updatedAt: String

        public init(_ model: TaskItem) {
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

        public func toModel() -> TaskItem {
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

        public func apply(_ model: TaskItem) {
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
public typealias LogEntity = FlashSchemaV2.LogEntity
public typealias EmotionEntity = FlashSchemaV2.EmotionEntity
public typealias TaskEntity = FlashSchemaV2.TaskEntity

/// V1→V2 轻量迁移：纯增列（可选属性），无数据变换
public enum FlashMigrationPlan: SchemaMigrationPlan, Sendable {
    public static var schemas: [any VersionedSchema.Type] {
        [FlashSchemaV1.self, FlashSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: FlashSchemaV1.self, toVersion: FlashSchemaV2.self)]
    }
}
