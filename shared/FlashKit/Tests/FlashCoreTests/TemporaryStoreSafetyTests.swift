// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

/// F-07：持久化容器打不开、降级为内存临时存储时，不得做任何会改写磁盘外状态的事，
/// 也不得把临时库的导出当作完整备份交给用户（日后覆盖导入会抹掉真实数据）。
@MainActor
@Suite("内存降级临时存储的安全边界（F-07）")
struct TemporaryStoreSafetyTests {
    private func makeRepo(temporary: Bool) -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true), isTemporaryStore: temporary)
    }

    private func task(_ id: String) -> TaskItem {
        TaskItem(id: id, title: "交周报", notes: nil, colorTag: .memo, importance: 0,
                 dueKind: .allDay, dueDate: "2999-01-01", dueAt: nil, timeZone: nil,
                 reminderAt: "2999-01-01T01:00:00.000Z", completedAt: nil,
                 createdAt: "2026-10-30T00:00:00.000Z", updatedAt: "2026-10-30T00:00:00.000Z")
    }

    private func log(_ id: String) -> LogItem {
        LogItem(id: id, content: "对端记录", colorTag: .daily, category: .log, importance: 0,
                createdAt: "2026-10-23T08:00:00.000Z", recordDate: "2026-10-23")
    }

    // MARK: - 装配标记

    @Test func assemblyMarksFallbackRepositoryAsTemporary() throws {
        let healthy = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        #expect(!healthy.isTemporaryStore)
        #expect(!(try healthy.snapshot().isFromTemporaryStore))

        let temporary = makeRepo(temporary: true)
        #expect(temporary.isTemporaryStore)
        #expect(try temporary.snapshot().isFromTemporaryStore)
    }

    // MARK: - 真实库打不开 → 临时模式 → 恢复后原数据完好

    /// 临时目录里的库文件集（default.store 与 -wal/-shm），按文件名取原始字节
    private func storeFiles(in directory: URL) throws -> [String: Data] {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return try Dictionary(uniqueKeysWithValues: names.map {
            ($0, try Data(contentsOf: directory.appendingPathComponent($0)))
        })
    }

    private func makeStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-fallback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 生产装配入口在持久库打不开时进入临时模式，且不碰原库文件
    @Test func unreadableStoreAssemblesTemporaryRepositoryWithoutTouchingFile() throws {
        let directory = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("default.store")
        let damaged = Data("这不是一个 SQLite 数据库".utf8)
        try damaged.write(to: storeURL)

        let assembly = RepositoryEnvironment.makeDefault(storeURL: storeURL)
        #expect(assembly.didFallbackToMemory)
        #expect(assembly.repository.isTemporaryStore)
        #expect(try assembly.repository.snapshot().isFromTemporaryStore)
        #expect(try Data(contentsOf: storeURL) == damaged)
    }

    /// 库暂时不可访问（目录无权限，相当于设备锁定时的数据保护）期间做完整的临时会话，
    /// 恢复访问后重新装配：原库逐字节未变，真实数据完整，临时会话的写入不会混入
    @Test func healthyStoreReturnsIntactAfterTemporarySession() async throws {
        let directory = try makeStoreDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let storeURL = directory.appendingPathComponent("default.store")
        let realTask = task("11111111-1111-1111-1111-111111111111")

        // 1. 正常启动写入真实数据
        do {
            let healthy = RepositoryEnvironment.makeDefault(storeURL: storeURL)
            try #require(!healthy.didFallbackToMemory)
            try healthy.repository.addLog(content: "真实记录", colorTag: .daily)
            try healthy.repository.saveTask(realTask)
        }
        let before = try storeFiles(in: directory)

        // 2. 库不可访问 → 临时模式；走一遍启动维护、导出、覆盖导入，并写入临时内容
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directory.path)
        let fallback = RepositoryEnvironment.makeDefault(storeURL: storeURL)
        try #require(fallback.didFallbackToMemory)
        let repository = fallback.repository
        var rebuildCalls = 0
        #expect(try await LaunchMaintenance.run(repository: repository) { _ in rebuildCalls += 1 }
                == .skippedTemporaryStore)
        try repository.addLog(content: "临时会话的记录", colorTag: .daily)
        await #expect(throws: BackupError.temporaryStore) {
            _ = try await BackupImportCoordinator.exportJSON(snapshot: try repository.snapshot(), appVersion: "test")
        }
        let incoming = try BackupService.parseStrict(try await BackupImportCoordinator.exportJSON(
            snapshot: FlashSnapshot(logs: [log("22222222-2222-2222-2222-222222222222")], emotions: [], tasks: []),
            appVersion: "test"))
        await #expect(throws: BackupError.temporaryStore) {
            _ = try await BackupImportCoordinator.apply(
                incoming, overwrite: true, previewSnapshot: try repository.snapshot(),
                repository: repository, rebuildReminders: { _ in rebuildCalls += 1 })
        }
        #expect(rebuildCalls == 0)

        // 3. 恢复访问：原库逐字节未变，重新装配回到正常模式且只有真实数据
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        #expect(try storeFiles(in: directory) == before)
        let recovered = RepositoryEnvironment.makeDefault(storeURL: storeURL)
        #expect(!recovered.didFallbackToMemory)
        #expect(!recovered.repository.isTemporaryStore)
        #expect(try recovered.repository.allLogs().map(\.content) == ["真实记录"])
        #expect(try recovered.repository.allTasks().map(\.id) == [realTask.id])
    }

    // MARK: - 启动维护：不撤提醒、不写小组件

    @Test func launchMaintenanceSkipsReminderRebuildForTemporaryStore() async throws {
        let repository = makeRepo(temporary: true)
        try repository.saveTask(task("11111111-1111-1111-1111-111111111111"))
        var rebuildCalls = 0
        let outcome = try await LaunchMaintenance.run(repository: repository) { _ in rebuildCalls += 1 }
        #expect(outcome == .skippedTemporaryStore)
        // 若照常重建，会以（几乎为空的）临时任务表撤掉用户磁盘上全部真实提醒
        #expect(rebuildCalls == 0)
    }

    @Test func launchMaintenanceRebuildsRemindersForHealthyStore() async throws {
        let repository = makeRepo(temporary: false)
        let saved = task("11111111-1111-1111-1111-111111111111")
        try repository.saveTask(saved)
        var rebuilt: [TaskItem]? = nil
        let outcome = try await LaunchMaintenance.run(repository: repository) { rebuilt = $0 }
        #expect(outcome == .completed)
        #expect(rebuilt?.map(\.id) == [saved.id])
    }

    // MARK: - 导出：临时快照绝不能成为「备份」

    @Test func exportRefusesSnapshotFromTemporaryStore() async throws {
        let repository = makeRepo(temporary: true)
        try repository.addLog(content: "本次启动才写的一条", colorTag: .daily)
        let snapshot = try repository.snapshot()
        await #expect(throws: BackupError.temporaryStore) {
            _ = try await BackupImportCoordinator.exportJSON(snapshot: snapshot, appVersion: "test")
        }
    }

    @Test func exportStillWorksForHealthyStore() async throws {
        let repository = makeRepo(temporary: false)
        try repository.addLog(content: "正常数据", colorTag: .daily)
        let json = try await BackupImportCoordinator.exportJSON(snapshot: try repository.snapshot(), appVersion: "test")
        #expect(try BackupService.parseStrict(json).logCount == 1)
    }

    // MARK: - 导入：不写临时库、不重建提醒

    @Test func applyRefusesTemporaryStoreWithoutWritingOrRebuilding() async throws {
        let json = try await BackupImportCoordinator.exportJSON(
            snapshot: FlashSnapshot(logs: [log("22222222-2222-2222-2222-222222222222")], emotions: [], tasks: []),
            appVersion: "test")
        let preview = try BackupService.parseStrict(json)
        let repository = makeRepo(temporary: true)
        var rebuildCalls = 0
        for overwrite in [false, true] {
            await #expect(throws: BackupError.temporaryStore) {
                _ = try await BackupImportCoordinator.apply(
                    preview, overwrite: overwrite, previewSnapshot: try repository.snapshot(),
                    repository: repository, rebuildReminders: { _ in rebuildCalls += 1 })
            }
        }
        #expect(try repository.allLogs().isEmpty)
        #expect(rebuildCalls == 0)
    }

    // MARK: - 提示文案：不得建议导出

    @Test func fallbackNoticeDoesNotAdviseExportingABackup() {
        let notice = RepositoryEnvironment.temporaryStoreNotice
        #expect(!notice.contains("导出备份"))
        #expect(!notice.contains("尽快导出"))
        #expect(notice.contains("未被改动"))
        #expect(notice.contains("导出与导入已暂停"))
        #expect(BackupError.temporaryStore.userMessage.contains("不能导出或导入"))
    }
}
