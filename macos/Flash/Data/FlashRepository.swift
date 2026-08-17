// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

/// 对应 Web 版 StorageAdapter / Android FlashRepository。
/// createdAt 使用 ISO-8601，recordDate 为 yyyy-MM-dd。
final class FlashRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
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
        context.insert(entity)
        try context.save()
    }

    @MainActor
    func updateLog(_ log: LogItem) throws {
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
        try context.save()
    }

    @MainActor
    func deleteLog(id: String) throws {
        if let entity = try fetchLog(id: id) {
            context.delete(entity)
            try context.save()
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
        context.insert(entity)
        try context.save()
    }

    @MainActor
    func deleteEmotion(id: String) throws {
        if let entity = try fetchEmotion(id: id) {
            context.delete(entity)
            try context.save()
        }
    }

    @MainActor
    func allEmotions() throws -> [EmotionRecord] {
        let descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Import / Export

    /// 覆盖式导入：清空后写入（对应 Web 版 overwriteImport）。
    /// 直接内联删除而不走 clearAll()：整个过程只有一次 save，
    /// 避免中间态 save 让 @Query 观察者看到「瞬间空库」的闪烁。
    @MainActor
    func replaceAll(logs: [LogItem], emotions: [EmotionRecord]) throws {
        try context.delete(model: LogEntity.self)
        try context.delete(model: EmotionEntity.self)
        for log in logs { upsertLogEntity(log) }
        for emotion in emotions { upsertEmotionEntity(emotion) }
        try context.save()
    }

    /// 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport）
    @MainActor
    func mergeAll(logs: [LogItem], emotions: [EmotionRecord]) throws {
        for log in logs { upsertLogEntity(log) }
        for emotion in emotions { upsertEmotionEntity(emotion) }
        try context.save()
    }

    @MainActor
    func clearAll() throws {
        try context.delete(model: LogEntity.self)
        try context.delete(model: EmotionEntity.self)
        try context.save()
    }

    // MARK: - Private

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
