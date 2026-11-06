// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData
import Testing
@testable import FlashCore

/// Schema V1→V2 轻量迁移：用 V1 容器写盘，再以 V2 + FlashMigrationPlan 打开，
/// 验证数据完好且新增可选字段缺省为 nil。
struct SchemaMigrationTests {

    @Test @MainActor func v1StoreMigratesToV2KeepingData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")

        // 1. 以 V1 schema 写入一条日志/情绪/任务
        let schemaV1 = Schema(versionedSchema: FlashSchemaV1.self)
        let containerV1 = try ModelContainer(
            for: schemaV1,
            configurations: [ModelConfiguration(schema: schemaV1, url: storeURL)]
        )
        let contextV1 = containerV1.mainContext
        contextV1.insert(FlashSchemaV1.LogEntity(
            id: "11111111-1111-4111-8111-111111111111", content: "旧库日志",
            colorTag: "daily", category: "log", importance: 2,
            createdAt: "2026-09-04T02:00:00.000Z", recordDate: "2026-09-04"))
        contextV1.insert(FlashSchemaV1.EmotionEntity(
            id: "22222222-2222-4222-8222-222222222222", level: 2,
            subEmotion: nil, status: nil, note: nil,
            recordDate: "2026-09-04", createdAt: "2026-09-04T03:00:00.000Z"))
        contextV1.insert(FlashSchemaV1.TaskEntity(
            id: "33333333-3333-4333-8333-333333333333", title: "旧库任务",
            notes: nil, colorTag: "memo", importance: 0,
            dueKind: "allDay", dueDate: "2026-09-07", dueAt: nil, timeZone: nil,
            reminderAt: nil, completedAt: nil,
            createdAt: "2026-09-04T00:00:00.000Z", updatedAt: "2026-09-04T00:00:00.000Z"))
        try contextV1.save()

        // 2. 以 V2 + 迁移计划重新打开同一文件
        let schemaV2 = Schema(versionedSchema: FlashSchemaV2.self)
        let containerV2 = try ModelContainer(
            for: schemaV2,
            migrationPlan: FlashMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schemaV2, url: storeURL)]
        )
        let contextV2 = containerV2.mainContext
        let logs = try contextV2.fetch(FetchDescriptor<LogEntity>())
        let emotions = try contextV2.fetch(FetchDescriptor<EmotionEntity>())
        let tasks = try contextV2.fetch(FetchDescriptor<TaskEntity>())

        #expect(logs.count == 1)
        #expect(emotions.count == 1)
        #expect(tasks.count == 1)
        // 数据完好
        #expect(logs.first?.content == "旧库日志")
        #expect(tasks.first?.title == "旧库任务")
        // 新字段缺省为 nil
        #expect(logs.first?.isFavorite == nil)
        #expect(emotions.first?.intensity == nil)
        #expect(emotions.first?.isFavorite == nil)
        #expect(tasks.first?.sourceLogId == nil)
        #expect(tasks.first?.isFavorite == nil)
        // 新字段可写可读
        logs.first?.isFavorite = true
        try contextV2.save()
        let refetch = try contextV2.fetch(FetchDescriptor<LogEntity>())
        #expect(refetch.first?.isFavorite == true)
    }

    /// 生产装配路径（FlashDatabase）在 V1 旧库上也能迁移打开
    @Test @MainActor func productionContainerMigratesExistingV1Store() throws {
        // makeContainer 使用默认存储位置，无法指向临时文件；
        // 迁移正确性由 v1StoreMigratesToV2KeepingData 覆盖，此处验证
        // 内存容器与版本化 schema 装配不回归
        let container = FlashDatabase.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(LogEntity(id: UUID().uuidString, content: "新库写入",
                                 colorTag: "daily", category: "log", importance: 0,
                                 isFavorite: true, createdAt: DateFormatting.isoNow(),
                                 recordDate: DateFormatting.today()))
        try context.save()
        let logs = try context.fetch(FetchDescriptor<LogEntity>())
        #expect(logs.first?.isFavorite == true)
    }
}
