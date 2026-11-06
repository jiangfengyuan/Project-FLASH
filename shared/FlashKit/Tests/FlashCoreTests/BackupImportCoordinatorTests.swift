// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

@MainActor
@Suite("BackupImportCoordinator 导入流水线")
struct BackupImportCoordinatorTests {
    private func makeRepo() -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
    }

    private func log(_ id: String, _ content: String) -> LogItem {
        LogItem(id: id, content: content, colorTag: .daily, category: .log, importance: 0,
                createdAt: "2026-10-23T08:00:00.000Z", recordDate: "2026-10-23")
    }

    /// 由另一台设备的快照导出再解析，得到真实的导入预览
    private func incomingPreview(_ logs: [LogItem]) async throws -> ImportPreview {
        let json = try await BackupImportCoordinator.exportJSON(
            snapshot: FlashSnapshot(logs: logs, emotions: [], tasks: []), appVersion: "test")
        return try BackupService.parseStrict(json)
    }

    @Test func mergeKeepsLocalOnlyRecordsAndReportsCounts() async throws {
        let repository = makeRepo()
        try repository.updateLog(log("11111111-1111-1111-1111-111111111111", "本机"))
        let incoming = try await incomingPreview([log("22222222-2222-2222-2222-222222222222", "对端")])
        let preview = BackupImportCoordinator.analyzed(incoming, against: try repository.snapshot())
        #expect(preview.difference?.logs.added == 1)
        #expect(preview.difference?.logs.localOnly == 1)

        var rebuilt: [TaskItem]? = nil
        let outcome = try await BackupImportCoordinator.apply(
            preview, overwrite: false, previewSnapshot: nil, repository: repository,
            rebuildReminders: { rebuilt = $0 })
        guard case .imported(let message, let hasSkipped) = outcome else {
            Issue.record("应为 .imported，实际 \(outcome)"); return
        }
        #expect(message == "已导入 1 条日志、0 条情绪、0 个任务")
        #expect(!hasSkipped)
        #expect(rebuilt == [])
        #expect(try repository.allLogs().count == 2)
    }

    @Test func overwriteRechecksLocalChangesBeforeDeleting() async throws {
        let repository = makeRepo()
        try repository.updateLog(log("11111111-1111-1111-1111-111111111111", "本机"))
        let previewSnapshot = try repository.snapshot()
        let preview = BackupImportCoordinator.analyzed(
            try await incomingPreview([log("22222222-2222-2222-2222-222222222222", "对端")]),
            against: previewSnapshot)
        // 预览后本机又新增一条：覆盖必须中止并重算差异
        try repository.addLog(content: "预览后新增", colorTag: .daily)
        let outcome = try await BackupImportCoordinator.apply(
            preview, overwrite: true, previewSnapshot: previewSnapshot, repository: repository,
            rebuildReminders: { _ in })
        guard case .changedSincePreview(let refreshed, let current) = outcome else {
            Issue.record("应为 .changedSincePreview，实际 \(outcome)"); return
        }
        #expect(refreshed.difference?.logs.localOnly == 2)
        #expect(current.logs.count == 2)
        #expect(try repository.allLogs().count == 2)

        // 用重算后的快照再次确认，覆盖生效
        let second = try await BackupImportCoordinator.apply(
            refreshed, overwrite: true, previewSnapshot: current, repository: repository,
            rebuildReminders: { _ in })
        guard case .imported = second else { Issue.record("应为 .imported"); return }
        #expect(try repository.allLogs().map(\.content) == ["对端"])
    }

    @Test func reminderFailureDoesNotRollBackData() async throws {
        struct Failure: Error {}
        let repository = makeRepo()
        let preview = try await incomingPreview([log("22222222-2222-2222-2222-222222222222", "对端")])
        let outcome = try await BackupImportCoordinator.apply(
            preview, overwrite: false, previewSnapshot: nil, repository: repository,
            rebuildReminders: { _ in throw Failure() })
        guard case .importedRemindersFailed = outcome else { Issue.record("应为 .importedRemindersFailed"); return }
        #expect(try repository.allLogs().count == 1)
    }

    @Test func oversizedFileIsRejectedBeforeReading() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("flash-oversize-\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(BackupService.maxFileBytes + 1))
        try handle.close()
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: BackupError.self) {
            _ = try await BackupImportCoordinator.preview(
                fileAt: url, recovery: false, against: FlashSnapshot(logs: [], emotions: [], tasks: []))
        }
    }

    @Test func analysisTextListsDifferences() async throws {
        let preview = BackupImportCoordinator.analyzed(
            try await incomingPreview([log("22222222-2222-2222-2222-222222222222", "对端")]),
            against: FlashSnapshot(logs: [], emotions: [], tasks: []))
        let text = BackupImportCoordinator.analysisText(preview)
        #expect(text.hasPrefix("包含 1 条日志、0 条情绪、0 个任务"))
        #expect(text.contains("日志：新增 1 · 修改 0 · 相同 0 · 仅本机 0"))
    }
}
