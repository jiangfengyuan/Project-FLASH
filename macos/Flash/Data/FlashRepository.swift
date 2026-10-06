// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData

/// 三分区完整快照；Equatable 供覆盖导入前做 TOCTOU 重校验（预览快照 vs 当前数据）
struct FlashSnapshot: Equatable {
    let logs: [LogItem]
    let emotions: [EmotionRecord]
    let tasks: [TaskItem]
}

// MARK: - 调试灌注分批

#if DEBUG
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
#endif

/// 对应 Web 版 StorageAdapter / Android FlashRepository。
/// createdAt 使用 ISO-8601，recordDate 为 yyyy-MM-dd。
final class FlashRepository {
    private let container: ModelContainer
    private let beforeSave: () throws -> Void

    /// 写代际号：每次 commit 成功 +1。视图用它做 O(1) 变更检测（onChange/缓存键），
    /// 代替「每次 body 求值全表 toModel 后做值比较」。不能改用 @Query 实体数组的
    /// 相等比较：PersistentModel 的相等走身份，漏掉就地属性更新（编辑/勾选完成）。
    /// 仅在主线程读写（全部写路径经 @MainActor commit）。
    private(set) var revision = 0

    init(container: ModelContainer, beforeSave: @escaping () throws -> Void = {}) {
        self.container = container
        self.beforeSave = beforeSave
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: - Logs

    /// recordDate 为空时取今天；新建面板允许用户指定记录日期，必须透传而不是静默改回今天
    @MainActor
    func addLog(content: String, colorTag: ColorTag,
                category: Category = .log, importance: Int = 0,
                isFavorite: Bool? = nil,
                recordDate: Date? = nil) throws {
        let entity = LogEntity(
            id: UUID().uuidString,
            content: content,
            colorTag: colorTag.rawValue,
            category: category.rawValue,
            importance: min(max(importance, 0), 4),
            isFavorite: isFavorite,
            createdAt: DateFormatting.isoNow(),
            recordDate: recordDate.map(DateFormatting.dayString) ?? DateFormatting.today()
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
                                         isFavorite: log.isFavorite,
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
                    status: String? = nil, note: String? = nil,
                    intensity: Int? = nil) throws {
        let entity = EmotionEntity(
            id: UUID().uuidString,
            level: level.rawValue,
            subEmotion: subEmotion?.rawValue,
            status: status,
            note: note,
            // 强度限定 1–5（可选，nil = 未评）
            intensity: intensity.map { min(max($0, 1), 5) },
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
    func updateEmotion(_ emotion: EmotionRecord) throws {
        try commit {
            if let entity = try fetchEmotion(id: emotion.id) {
                entity.apply(emotion)
            } else {
                upsertEmotionEntity(emotion)
            }
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
        try tasksOnly()
    }

    /// 只取任务表（按 updatedAt 倒序）：启动时重建系统提醒等只需任务的场景使用，
    /// 避免 snapshot() 连带映射日志/情绪两张全表
    @MainActor
    func tasksOnly() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Favorites

    /// 收藏切换：三分区统一入口；isFavorite 为可选三态（nil 视为未收藏），写入时收敛为 Bool
    @MainActor
    func setLogFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchLog(id: id) {
            try commit { entity.isFavorite = isFavorite }
        }
    }

    @MainActor
    func setEmotionFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchEmotion(id: id) {
            try commit { entity.isFavorite = isFavorite }
        }
    }

    @MainActor
    func setTaskFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchTask(id: id) {
            try commit { entity.isFavorite = isFavorite }
        }
    }

    // MARK: - Import / Export

    #if DEBUG
    /// 合成数据灌注（性能基线专用）：分批 commit，避免单次超大事务
    @MainActor
    func seedBulk(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem]) throws {
        let batchSize = 2000
        for batch in logs.chunked(into: batchSize) {
            try commit { batch.forEach(upsertLogEntity) }
        }
        for batch in emotions.chunked(into: batchSize) {
            try commit { batch.forEach(upsertEmotionEntity) }
        }
        for batch in tasks.chunked(into: batchSize) {
            try commit { batch.forEach { context.insert(TaskEntity($0)) } }
        }
    }
    #endif

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

    // MARK: - Widget Summary

    /// 桌面小组件（WidgetKit）当日摘要：计数走 fetchCount、情绪只取当日行，
    /// 避免快照刷新触发全表 toModel 映射。由 WidgetSnapshot.refresh 调用。
    @MainActor
    func widgetTodaySummary() throws -> (logCount: Int, openTaskCount: Int, dominantEmotion: EmotionLevel?) {
        let today = DateFormatting.today()
        let logPredicate = #Predicate<LogEntity> { $0.recordDate == today }
        let logCount = try context.fetchCount(FetchDescriptor<LogEntity>(predicate: logPredicate))
        // calendarDate 是计算属性无法进 #Predicate；任务表规模有限，全量过滤可接受
        let openTaskCount = try tasksOnly().filter { !$0.isCompleted && $0.calendarDate == today }.count
        let emotionPredicate = #Predicate<EmotionEntity> { $0.recordDate == today }
        let emotions = try context.fetch(FetchDescriptor<EmotionEntity>(
            predicate: emotionPredicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        // 主导情绪 = 出现频次最高；并列时取 createdAt 最新（fetch 已按最新在前）
        var counts: [Int: Int] = [:]
        for entity in emotions { counts[entity.level, default: 0] += 1 }
        var dominant: EmotionLevel?
        var dominantCount = 0
        for entity in emotions {
            let count = counts[entity.level] ?? 0
            if count > dominantCount {
                dominantCount = count
                dominant = EmotionLevel(rawValue: entity.level)
            }
        }
        return (logCount, openTaskCount, dominant)
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
            revision += 1
            // 桌面小组件（WidgetKit）：每次提交成功后刷新共享快照；
            // 组容器不可用（adhoc 构建）时零成本 no-op
            WidgetSnapshot.refresh(repository: self)
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
                               isFavorite: log.isFavorite,
                               createdAt: log.createdAt, recordDate: log.recordDate)
        context.insert(entity) // SwiftData 对 .unique id 冲突执行更新
    }

    @MainActor
    private func upsertEmotionEntity(_ emotion: EmotionRecord) {
        let entity = EmotionEntity(id: emotion.id, level: emotion.level.rawValue,
                                   subEmotion: emotion.subEmotion?.rawValue,
                                   status: emotion.status, note: emotion.note,
                                   intensity: emotion.intensity,
                                   isFavorite: emotion.isFavorite,
                                   recordDate: emotion.recordDate,
                                   createdAt: emotion.createdAt)
        context.insert(entity)
    }
}

// MARK: - Widget Snapshot 刷新

/// 本扩展依赖 FlashRepository，只在主 target（Flash）编译；
/// Widget target 仅共享 WidgetSnapshot.swift 的协议与读写器。
extension WidgetSnapshot {
    /// 从仓储聚合当日摘要并写入快照。组不可用时（adhoc 构建）零成本直接返回。
    /// 挂点：FlashApp 启动 `.task` 与 `FlashRepository.commit()` 成功后
    /// （参照 TaskReminderScheduler.rebuild 的挂接方式；读取失败静默忽略）。
    @MainActor
    static func refresh(repository: FlashRepository) {
        guard WidgetSnapshotStore.containerDirectory != nil else { return }
        guard let summary = try? repository.widgetTodaySummary() else { return }
        WidgetSnapshotWriter.write(WidgetSnapshot(
            recordDate: DateFormatting.today(),
            todayLogCount: summary.logCount,
            openTaskCount: summary.openTaskCount,
            dominantEmotionEmoji: summary.dominantEmotion?.emoji,
            generatedAt: DateFormatting.isoNow()
        ))
    }
}
