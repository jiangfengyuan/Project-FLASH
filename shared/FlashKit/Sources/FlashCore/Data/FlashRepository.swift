// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 三分区完整快照；Equatable 供覆盖导入前做 TOCTOU 重校验（预览快照 vs 当前数据）
public struct FlashSnapshot: Equatable, Sendable {
    public let logs: [LogItem]
    public let emotions: [EmotionRecord]
    public let tasks: [TaskItem]
    /// 快照取自内存降级的临时存储：只含本次启动后写入的内容，不是完整数据，
    /// 导出路径必须拒绝（否则日后「覆盖导入」会用它抹掉真实数据，见 F-07）
    public let trash: [TrashItem]
    public let preferences: LibraryPreferences
    public let automaticTags: [String:[String]]
    public let library: PersonalLibrary
    public let isFromTemporaryStore: Bool

    public init(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem],
                isFromTemporaryStore: Bool = false, library: PersonalLibrary = .init(), trash: [TrashItem] = [], preferences: LibraryPreferences = .init(), automaticTags: [String:[String]] = [:]) {
        self.trash = trash; self.preferences = preferences; self.automaticTags = automaticTags
        self.library = library
        self.logs = logs
        self.emotions = emotions
        self.tasks = tasks
        self.isFromTemporaryStore = isFromTemporaryStore
    }
}

// MARK: - 调试灌注分批

#if DEBUG
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
#endif

/// 日志 / 灵感分区的变更（提交成功后发出），供系统搜索索引等派生状态增量同步
public enum LogChange: Equatable, Sendable {
    /// 新增或改动（含收藏切换、合并导入）
    case upserted([LogItem])
    case deleted([String])
    /// 整表替换或清空（覆盖导入、清空全部、调试灌注）：派生状态应整体重建
    case reset
}

/// 对应 Web 版 StorageAdapter / Android FlashRepository。
/// createdAt 使用 ISO-8601，recordDate 为 yyyy-MM-dd。
@Observable public final class FlashRepository {
    let container: ModelContainer
    private let beforeSave: () throws -> Void

    /// 写代际号：每次 commit 成功 +1。视图用它做 O(1) 变更检测（onChange/缓存键），
    /// 代替「每次 body 求值全表 toModel 后做值比较」。不能改用 @Query 实体数组的
    /// 相等比较：PersistentModel 的相等走身份，漏掉就地属性更新（编辑/勾选完成）。
    /// 仅在主线程读写（全部写路径经 @MainActor commit）。
    public private(set) var revision = 0
    public private(set) var contentRevision = 0
    @ObservationIgnored public var onTextChange: (@MainActor (String,String) -> Void)?

    /// true：持久化容器打不开、本次运行使用内存降级的临时存储（RepositoryEnvironment 装配时标记）。
    /// 此时真实数据仍在磁盘上未被改动；任何会改写「磁盘外」状态的副作用（系统提醒、小组件快照、
    /// 灵感已读状态）和导入导出都必须跳过，避免用空库覆盖真实状态（F-07）。
    public let isTemporaryStore: Bool

    /// 日志 / 灵感变更回调：只在 commit 成功后、主线程调用；失败回滚的写入不会发出
    public var onLogChange: (@MainActor (LogChange) -> Void)?

    public init(container: ModelContainer, isTemporaryStore: Bool = false,
                beforeSave: @escaping () throws -> Void = {}) {
        self.container = container
        self.isTemporaryStore = isTemporaryStore
        self.beforeSave = beforeSave
    }

    @MainActor
    var context: ModelContext { container.mainContext }

    // MARK: - Logs

    /// recordDate 为空时取今天；新建面板允许用户指定记录日期，必须透传而不是静默改回今天。
    /// `id` 为 nil 时新生成；分享收件箱导入传入条目 id，使中断后重放不产生重复记录
    @MainActor
    public func addLog(id: String? = nil, content: String, colorTag: ColorTag,
                category: Category = .log, importance: Int = 0,
                isFavorite: Bool? = nil,
                recordDate: Date? = nil) throws {
        let entity = LogEntity(
            id: id ?? UUID().uuidString,
            content: content,
            colorTag: colorTag.rawValue,
            category: category.rawValue,
            importance: min(max(importance, 0), 4),
            isFavorite: isFavorite,
            createdAt: DateFormatting.isoNow(),
            recordDate: recordDate.map(DateFormatting.dayString) ?? DateFormatting.today()
        )
        try commit { context.insert(entity) }
        onTextChange?("log:"+entity.id,entity.content)
        onLogChange?(.upserted([entity.toModel()]))
    }

    @MainActor
    public func updateLog(_ log: LogItem, tags: TagDraft? = nil) throws {
        let textChanged = try fetchLog(id:log.id)?.content != log.content
        try commit {
            if let entity = try fetchLog(id: log.id) {
                entity.apply(log)
                if log.category != .idea {
                    var library = try personalLibrary(); library.reminders.removeAll { $0.id == log.id }; try writeLibrary(library)
                }
            } else {
                context.insert(LogEntity(id: log.id, content: log.content,
                                         colorTag: log.colorTag.rawValue,
                                         category: log.category.rawValue,
                                         importance: log.importance,
                                         isFavorite: log.isFavorite,
                                         createdAt: log.createdAt,
                                         recordDate: log.recordDate))
            }
            if let tags { try writeTagDraft(tags,key:"log:"+log.id) }
        }
        if textChanged { onTextChange?("log:"+log.id,log.content) }
        onLogChange?(.upserted([log]))
    }

    @MainActor
    public func deleteLog(id: String) throws {
        if let entity = try fetchLog(id: id) {
            try commit { context.delete(entity); try removeLibraryRecord("log:\(id)") }
            onLogChange?(.deleted([id]))
        }
    }

    /// 按 id 判断记录是否存在（收件箱去重、Spotlight 结果回跳校验）
    @MainActor
    public func containsLog(id: String) throws -> Bool {
        try fetchLog(id: id) != nil
    }

    @MainActor
    public func allLogs() throws -> [LogItem] {
        let descriptor = FetchDescriptor<LogEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    /// 只取灵感（灵感提醒计算未读用，按创建时间倒序）
    @MainActor
    public func allIdeas() throws -> [LogItem] {
        let idea = Category.idea.rawValue
        let descriptor = FetchDescriptor<LogEntity>(
            predicate: #Predicate { $0.category == idea },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Emotions

    @MainActor
    public func addEmotion(level: EmotionLevel, subEmotion: SubEmotion?,
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
    public func deleteEmotion(id: String) throws {
        if let entity = try fetchEmotion(id: id) {
            try commit { context.delete(entity); try removeLibraryRecord("emotion:\(id)") }
        }
    }

    @MainActor
    public func allEmotions() throws -> [EmotionRecord] {
        let descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Tasks

    @MainActor
    public func saveTask(_ task: TaskItem, tags: TagDraft? = nil) throws {
        let previous = try fetchTask(id:task.id)
        let textChanged = previous?.title != task.title || previous?.notes != task.notes
        try commit {
            if let entity = try fetchTask(id: task.id) {
                entity.apply(task)
            } else {
                context.insert(TaskEntity(task))
            }
            if let tags { try writeTagDraft(tags,key:"task:"+task.id) }
        }
        if textChanged { onTextChange?("task:"+task.id,task.title+"\n"+(task.notes ?? "")) }
    }

    @MainActor
    public func deleteTask(id: String) throws {
        if let entity = try fetchTask(id: id) {
            try commit { context.delete(entity); try removeLibraryRecord("task:\(id)") }
        }
    }

    @MainActor
    public func allTasks() throws -> [TaskItem] {
        try tasksOnly()
    }

    /// 只取任务表（按 updatedAt 倒序）：启动时重建系统提醒等只需任务的场景使用，
    /// 避免 snapshot() 连带映射日志/情绪两张全表
    @MainActor
    public func tasksOnly() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toModel() }
    }

    // MARK: - Favorites

    /// 收藏切换：三分区统一入口；isFavorite 为可选三态（nil 视为未收藏），写入时收敛为 Bool
    @MainActor
    public func setLogFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchLog(id: id) {
            try commit { entity.isFavorite = isFavorite }
            onLogChange?(.upserted([entity.toModel()]))
        }
    }

    @MainActor
    public func setEmotionFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchEmotion(id: id) {
            try commit { entity.isFavorite = isFavorite }
        }
    }

    @MainActor
    public func setTaskFavorite(id: String, _ isFavorite: Bool) throws {
        if let entity = try fetchTask(id: id) {
            try commit { entity.isFavorite = isFavorite }
        }
    }

    // MARK: - Import / Export

    #if DEBUG
    /// 合成数据灌注（性能基线专用）：分批 commit，避免单次超大事务
    @MainActor
    public func seedBulk(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem]) throws {
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
        onLogChange?(.reset)
    }
    #endif

    /// Capture all portable sections through one repository boundary. The
    /// synchronous MainActor read prevents app writes from interleaving between
    /// sections, and callers can no longer accidentally assemble three unrelated
    /// reads or silently substitute empty arrays when injection is missing.
    @MainActor
    public func snapshot() throws -> FlashSnapshot {
        FlashSnapshot(logs: try allLogs(),
                      emotions: try allEmotions(),
                      tasks: try allTasks(),
                      isFromTemporaryStore: isTemporaryStore, library: try personalLibrary(), trash: try trashItems(), preferences: try preferences(), automaticTags: try automaticTagLinks())
    }

    /// 覆盖式导入：清空后写入（对应 Web 版 overwriteImport）。
    /// 直接内联删除而不走 clearAll()：整个过程只有一次 save，
    /// 避免中间态 save 让 @Query 观察者看到「瞬间空库」的闪烁。
    @MainActor
    public func replaceAll(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = [], library: PersonalLibrary = .init(), trash: [TrashItem] = [], preferences: LibraryPreferences = .init(), automaticTags: [String:[String]] = [:]) throws {
        try commit {
            try deleteAllEntities()
            try writeLibrary(library)
            try writeTrash(trash,merge:false); try writePreferences(preferences)
            try writeAutomaticOrigins(automaticTags)
            for log in logs { upsertLogEntity(log) }
            for emotion in emotions { upsertEmotionEntity(emotion) }
            for task in tasks { context.insert(TaskEntity(task)) }
        }
        onLogChange?(.reset)
    }

    /// 合并式导入：同 id 覆盖，其余保留（对应 Web 版 mergeImport）
    @MainActor
    public func mergeAll(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = [], library: PersonalLibrary? = nil, trash: [TrashItem] = [], preferences: LibraryPreferences? = nil, automaticTags: [String:[String]] = [:]) throws {
        try commit {
            if let library {
                let previous = try personalLibrary(), origins = try automaticTagLinks()
                let merged = try previous.merging(library)
                try writeLibrary(merged)
                for (key,ids) in library.links {
                    for id in ids {
                        guard let incoming = library.tags.first(where:{ $0.id == id }), let mapped = merged.tags.first(where:{ $0.normalized == incoming.normalized }) else { continue }
                        let manualBefore = previous.links[key]?.contains(mapped.id) == true && origins[key]?.contains(mapped.id) != true
                        let automatic = automaticTags[key]?.contains(id) == true && !manualBefore
                        for row in try context.fetch(FetchDescriptor<LibraryTagLinkEntity>(predicate:#Predicate { $0.recordKey == key })) where row.tagID == mapped.id { row.automatic = automatic }
                    }
                }
            }
            try writeTrash(trash,merge:true); if let preferences { try writePreferences(preferences) }
            for log in logs { upsertLogEntity(log) }
            for emotion in emotions { upsertEmotionEntity(emotion) }
            for task in tasks {
                if let local = try fetchTask(id: task.id) {
                    if try BackupService.normalizedTimestamp(task.updatedAt) >= BackupService.normalizedTimestamp(local.updatedAt) { local.apply(task) }
                } else {
                    context.insert(TaskEntity(task))
                }
            }
            var current = try personalLibrary()
            let records = LibraryRecord.records(try snapshot())
            let keys = Set(records.map(\.key)), ideas = Set(records.filter { $0.kind == .idea }.map(\.recordID))
            current.links = current.links.filter { keys.contains($0.key) }
            current.reminders.removeAll { !ideas.contains($0.id) }
            try current.validated(records: records)
            try writeLibrary(current)
        }
        if !logs.isEmpty { onLogChange?(.upserted(logs)) }
    }

    @MainActor
    public func clearAll() throws {
        try commit {
            try deleteAllEntities()
        }
        onLogChange?(.reset)
    }

    @MainActor public func personalLibrary(includeLinks: Bool = true) throws -> PersonalLibrary {
        if supportsV4 { return try readLibraryV4(includeLinks:includeLinks) }
        guard container.schema.entities.contains(where: { $0.name == "PersonalLibraryEntity" }) else { return .init() }
        guard let entity = try context.fetch(FetchDescriptor<PersonalLibraryEntity>()).first else { return .init() }
        return try JSONDecoder().decode(PersonalLibrary.self, from: entity.payload)
    }
    @MainActor func writeLibrary(_ value: PersonalLibrary) throws {
        if supportsV4 { try writeLibraryV4(value); return }
        guard container.schema.entities.contains(where: { $0.name == "PersonalLibraryEntity" }) else {
            if value != PersonalLibrary() { throw BackupError.contract("/personalLibrary") }; return
        }
        let data = try JSONEncoder().encode(value)
        if let entity = try context.fetch(FetchDescriptor<PersonalLibraryEntity>()).first { entity.payload = data }
        else { context.insert(PersonalLibraryEntity(payload: data)) }
    }
    @MainActor public func savePersonalLibrary(_ value: PersonalLibrary) throws {
        guard !isTemporaryStore else { throw BackupError.temporaryStore }
        // Metadata edits validate structure without mapping the content tables.
        try value.validated(recordKeys:Set(value.links.keys),ideaIDs:Set(value.reminders.map(\.id)))
        let previous = try personalLibrary()
        for key in value.links.keys where previous.links[key] == nil {
            guard try textForRecord(key) != nil else { throw BackupError.contract("/personalLibrary/links") }
        }
        for rule in value.reminders where !previous.reminders.contains(where:{ $0.id == rule.id }) {
            guard try fetchLog(id:rule.id)?.category == Category.idea.rawValue else { throw BackupError.contract("/personalLibrary/reminders") }
        }
        try commit(metadataOnly:true) { try writeLibrary(value) }
    }
    @MainActor func removeLibraryRecord(_ key: String) throws {
        if supportsV4 {
            for link in try context.fetch(FetchDescriptor<LibraryTagLinkEntity>(predicate:#Predicate { $0.recordKey == key })) { context.delete(link) }
            if key.hasPrefix("log:"), let metadata = try context.fetch(FetchDescriptor<PersonalLibraryEntity>()).first {
                var library = try JSONDecoder().decode(PersonalLibrary.self,from:metadata.payload)
                let id = String(key.dropFirst(4))
                if library.reminders.contains(where:{ $0.id == id }) {
                    library.reminders.removeAll { $0.id == id }
                    metadata.payload = try JSONEncoder().encode(library)
                }
            }
        } else {
            var library = try personalLibrary()
            library.links.removeValue(forKey:key)
            if key.hasPrefix("log:") { library.reminders.removeAll { $0.id == String(key.dropFirst(4)) } }
            try writeLibrary(library)
        }
    }

    // MARK: - Widget Summary

    /// 桌面小组件（WidgetKit）当日摘要：计数走 fetchCount、情绪只取当日行，
    /// 避免快照刷新触发全表 toModel 映射。由 WidgetSnapshot.refresh 调用。
    @MainActor
    public func widgetTodaySummary() throws -> (logCount: Int, openTaskCount: Int, dominantEmotion: EmotionLevel?) {
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
    func commit(metadataOnly: Bool = false, _ mutation: () throws -> Void) throws {
        do {
            try mutation()
            try beforeSave()
            try context.save()
            revision += 1
            if !metadataOnly { contentRevision += 1 }
            // 桌面小组件（WidgetKit）：每次提交成功后刷新共享快照；
            // 组容器不可用（adhoc 构建）时零成本 no-op
            if !metadataOnly { WidgetSnapshot.refresh(repository: self) }
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
        try writeLibrary(.init())
        try writeTrash([],merge:false)
        try writePreferences(.init())
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
    func fetchLog(id: String) throws -> LogEntity? {
        let predicate = #Predicate<LogEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1 // id 唯一，命中即停
        return try context.fetch(descriptor).first
    }

    @MainActor
    func fetchEmotion(id: String) throws -> EmotionEntity? {
        let predicate = #Predicate<EmotionEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    func fetchTask(id: String) throws -> TaskEntity? {
        let predicate = #Predicate<TaskEntity> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    func upsertLogEntity(_ log: LogItem) {
        let entity = LogEntity(id: log.id, content: log.content,
                               colorTag: log.colorTag.rawValue,
                               category: log.category.rawValue,
                               importance: log.importance,
                               isFavorite: log.isFavorite,
                               createdAt: log.createdAt, recordDate: log.recordDate)
        context.insert(entity) // SwiftData 对 .unique id 冲突执行更新
    }

    @MainActor
    func upsertEmotionEntity(_ emotion: EmotionRecord) {
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
    public static func refresh(repository: FlashRepository, unreadIdeaCount: Int? = nil) {
        // 临时存储只有本次启动的内容：不能用它覆盖小组件上的真实摘要
        guard !repository.isTemporaryStore else { return }
        guard let directory = WidgetSnapshotStore.containerDirectory else { return }
        guard let summary = try? repository.widgetTodaySummary() else { return }
        // 未读灵感数由宿主（iOS 灵感提醒）提供；写库路径不知道已读状态，沿用上一份快照的值
        let unread = unreadIdeaCount ?? WidgetSnapshotReader.read(from: directory)?.unreadIdeaCount
        WidgetSnapshotWriter.write(WidgetSnapshot(
            recordDate: DateFormatting.today(),
            todayLogCount: summary.logCount,
            openTaskCount: summary.openTaskCount,
            dominantEmotionEmoji: summary.dominantEmotion?.emoji,
            generatedAt: DateFormatting.isoNow(),
            unreadIdeaCount: unread
        ))
        // 通知系统重载时间线（此前只写快照、从不重载，小组件要等下一次整点刷新）
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
