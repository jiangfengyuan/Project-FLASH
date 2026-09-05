// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

struct FlashSnapshot {
    let logs: [LogItem]
    let emotions: [EmotionRecord]
    let tasks: [TaskItem]
}

/// 对应 Web 版 StorageAdapter / Android FlashRepository。
/// createdAt 使用 ISO-8601，recordDate 为 yyyy-MM-dd。
final class FlashRepository {
    private let container: ModelContainer
    private let beforeSave: () throws -> Void

    init(container: ModelContainer, beforeSave: @escaping () throws -> Void = {}) {
        self.container = container
        self.beforeSave = beforeSave
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: - Logs

    @MainActor
    func addLog(content: String, colorTag: ColorTag,
                category: Category = .log, importance: Int = 0) throws {
        let entity = LogEntity(
            id: UUID().uuidString,
            content: content,
            colorTag: colorTag.rawValue,
            category: category.rawValue,
            importance: min(max(importance, 0), 4),
            createdAt: DateFormatting.isoNow(),
            recordDate: DateFormatting.today()
        )
        try commit { context.insert(entity) }
    }

    @MainActor
    func updateLog(_ log: LogItem) throws {
        try commit {
            if let entity = try fetchLog(id: log.id) {
                entity.apply(log)
            } else {
                context.insert(LogEntity(id: log.id, content: log.content,
                                         colorTag: log.colorTag.rawValue,
                                         category: log.category.rawValue,
                                         importance: log.importance,
                                         createdAt: log.createdAt,
                                         recordDate: log.recordDate))
            }
        }
    }

    @MainActor
    func deleteLog(id: String) throws {
        if let entity = try fetchLog(id: id) {
            try commit { context.delete(entity) }
        }
    }

    @MainActor
    func allLogs() throws -> [LogItem] {
        let descriptor = FetchDescriptor<LogEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Emotions

    @MainActor
    func addEmotion(level: EmotionLevel, subEmotion: SubEmotion?,
                    status: String? = nil, note: String? = nil) throws {
        let entity = EmotionEntity(
            id: UUID().uuidString,
            level: level.rawValue,
            subEmotion: subEmotion?.rawValue,
            status: status,
            note: note,
            recordDate: DateFormatting.today(),
            createdAt: DateFormatting.isoNow()
        )
        try commit { context.insert(entity) }
    }

    @MainActor
    func deleteEmotion(id: String) throws {
        if let entity = try fetchEmotion(id: id) {
            try commit { context.delete(entity) }
        }
    }

    @MainActor
    func allEmotions() throws -> [EmotionRecord] {
        let descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Tasks

    @MainActor
    func saveTask(_ task: TaskItem) throws {
        try commit {
            if let entity = try fetchTask(id: task.id) {
                entity.apply(task)
            } else {
                context.insert(TaskEntity(task))
            }
        }
    }

    @MainActor
    func deleteTask(id: String) throws {
        if let entity = try fetchTask(id: id) {
            try commit { context.delete(entity) }
        }
    }

    @MainActor
    func allTasks() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Import / Export

    /// Capture all portable sections through one repository boundary. The
    /// synchronous MainActor read prevents app writes from interleaving between
    /// sections, and callers can no longer accidentally assemble three unrelated
    /// reads or silently substitute empty arrays when injection is missing.
    @MainActor
    func snapshot() throws -> FlashSnapshot {
        FlashSnapshot(logs: try allLogs(),
                      emotions: try allEmotions(),
                      tasks: try allTasks())
    }

    /// 覆盖式导入：清空后写入（对应 Web 版 overwriteImport）。
    /// 直接内联删除而不走 clearAll()：整个过程只有一次 save，
    /// 避免中间态 save 让 @Query 观察者看到「瞬间空库」的闪烁。
    @MainActor
    func replaceAll(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = []) throws {
        try commit {
            try deleteAllEntities()
            for log in logs { upsertLogEntity(log) }
            for emotion in emotions { upsertEmotionEntity(emotion) }
            for task in tasks { context.insert(TaskEntity(task)) }
        }
    }

    /// 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport）
    @MainActor
    func mergeAll(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = []) throws {
        try commit {
            for log in logs { upsertLogEntity(log) }
            for emotion in emotions { upsertEmotionEntity(emotion) }
            for task in tasks {
                if let local = try fetchTask(id: task.id) {
                    if try BackupService.normalizedTimestamp(task.updatedAt) >= BackupService.normalizedTimestamp(local.updatedAt) { local.apply(task) }
                } else {
                    context.insert(TaskEntity(task))
                }
            }
        }
    }

    @MainActor
    func clearAll() throws {
        try commit {
            try deleteAllEntities()
        }
    }

    // MARK: - Private

    /// A failed save must not leave destructive pending changes visible in the
    /// shared main context or allow a later unrelated save to commit them.
    @MainActor
    private func commit(_ mutation: () throws -> Void) throws {
        do {
            try mutation()
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// SwiftData's model-wide delete is a store-level operation and is not
    /// reliably reversed by `ModelContext.rollback()`. Deleting fetched
    /// instances keeps every removal in the context transaction, so a failed
    /// save restores the pre-mutation graph instead of leaking a pending wipe.
    @MainActor
    private func deleteAllEntities() throws {
        for entity in try context.fetch(FetchDescriptor<LogEntity>()) {
            context.delete(entity)
        }
        for entity in try context.fetch(FetchDescriptor<EmotionEntity>()) {
            context.delete(entity)
        }
        for entity in try context.fetch(FetchDescriptor<TaskEntity>()) {
            context.delete(entity)
        }
    }

    @MainActor
    private func fetchLog(id: String) throws -> LogEntity? {
        let predicate = #Predicate<LogEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1 // id 唯一，命中即停
        return try context.fetch(descriptor).first
    }

    @MainActor
    private func fetchEmotion(id: String) throws -> EmotionEntity? {
        let predicate = #Predicate<EmotionEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private func fetchTask(id: String) throws -> TaskEntity? {
        let predicate = #Predicate<TaskEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private func upsertLogEntity(_ log: LogItem) {
        let entity = LogEntity(id: log.id, content: log.content,
                               colorTag: log.colorTag.rawValue,
                               category: log.category.rawValue,
                               importance: log.importance,
                               createdAt: log.createdAt, recordDate: log.recordDate)
        context.insert(entity) // SwiftData 对 .unique id 冲突执行更新
    }

    @MainActor
    private func upsertEmotionEntity(_ emotion: EmotionRecord) {
        let entity = EmotionEntity(id: emotion.id, level: emotion.level.rawValue,
                                   subEmotion: emotion.subEmotion?.rawValue,
                                   status: emotion.status, note: emotion.note,
                                   recordDate: emotion.recordDate,
                                   createdAt: emotion.createdAt)
        context.insert(entity)
    }
}
