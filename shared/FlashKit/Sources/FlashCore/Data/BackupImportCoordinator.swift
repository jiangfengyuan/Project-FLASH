// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 备份导入/导出流水线（macOS 设置页与 iOS 设置页共用；平台只负责选文件与呈现）。
///
/// 导入：读文件（50 MB 上限）→ 严格解析 v2 或恢复解析 → 与本机快照做差异分析 → 预览 →
/// 合并或覆盖写库（覆盖前 TOCTOU 重校验）→ 重建系统提醒。
/// 序列化、解析与差异分析在后台执行；写库经 `@MainActor` 的 FlashRepository。
public enum BackupImportCoordinator {
    /// 确认导入后的结果
    public enum ApplyOutcome: Sendable {
        /// 已写入；`message` 为结果文案，`hasSkipped` 为 true 时宜用弹窗展示（含异常明细）
        case imported(message: String, hasSkipped: Bool)
        /// 已写入，但系统提醒重建失败
        case importedRemindersFailed
        /// 覆盖前发现本地数据在预览后有变化：差异已按当前数据重算，需用户再次确认
        case changedSincePreview(preview: ImportPreview, snapshot: FlashSnapshot)
    }

    // MARK: - 导出

    /// 严格 v2 导出 JSON（后台序列化）
    public static func exportJSON(snapshot: FlashSnapshot, appVersion: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try BackupService.exportStrictJSON(logs: snapshot.logs,
                                               emotions: snapshot.emotions,
                                               tasks: snapshot.tasks,
                                               appVersion: appVersion)
        }.value
    }

    // MARK: - 预览

    /// 从用户选择的文件生成导入预览：先查大小（超 50 MB 直接拒绝）再全量读入
    public static func preview(fileAt url: URL, recovery: Bool,
                               against snapshot: FlashSnapshot) async throws -> ImportPreview {
        try await Task.detached(priority: .userInitiated) {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize, size > BackupService.maxFileBytes {
                throw BackupError.fileTooLarge
            }
            let json = try BackupService.readJSON(from: url)
            let parsed = try recovery ? BackupService.parseRecovery(json) : BackupService.parseStrict(json)
            return analyzed(parsed, against: snapshot)
        }.value
    }

    /// 从局域网接收的 JSON 生成导入预览（只走严格 v2）
    public static func preview(json: String, against snapshot: FlashSnapshot) async throws -> ImportPreview {
        try await Task.detached(priority: .userInitiated) {
            analyzed(try BackupService.parseStrict(json), against: snapshot)
        }.value
    }

    /// 为预览附上与本机快照的差异分析
    public static func analyzed(_ preview: ImportPreview, against snapshot: FlashSnapshot) -> ImportPreview {
        var preview = preview
        preview.difference = BackupDiff.analyze(
            localLogs: snapshot.logs, localEmotions: snapshot.emotions,
            incomingLogs: preview.logs, incomingEmotions: preview.emotions,
            localTasks: snapshot.tasks, incomingTasks: preview.tasks)
        return preview
    }

    // MARK: - 写入

    /// 确认导入。覆盖会删除本地独有记录：预览后本地数据若已变化，按当前数据重算差异并返回
    /// `.changedSincePreview`，不得静默删除预览后新增的记录（对齐 HarmonyOS applyBackup）。
    /// 写库失败直接抛出；提醒重建失败不回滚数据，返回 `.importedRemindersFailed`。
    @MainActor
    public static func apply(_ preview: ImportPreview, overwrite: Bool,
                             previewSnapshot: FlashSnapshot?,
                             repository: FlashRepository,
                             rebuildReminders: (([TaskItem]) async throws -> Void)? = nil) async throws -> ApplyOutcome {
        if overwrite {
            let current = try repository.snapshot()
            guard previewSnapshot == current else {
                return .changedSincePreview(preview: analyzed(preview, against: current), snapshot: current)
            }
            try repository.replaceAll(logs: preview.logs, emotions: preview.emotions, tasks: preview.tasks)
        } else {
            try repository.mergeAll(logs: preview.logs, emotions: preview.emotions, tasks: preview.tasks)
        }
        do {
            // 默认重建系统提醒；测试注入替身，避免触达通知中心
            let tasks = try repository.tasksOnly()
            if let rebuildReminders {
                try await rebuildReminders(tasks)
            } else {
                try await TaskReminderScheduler.shared.rebuild(tasks)
            }
        } catch {
            return .importedRemindersFailed
        }
        let skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
        var message = "已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、\(preview.taskCount) 个任务"
        if skipped > 0 { message += "（跳过异常数据 \(skipped) 条）" }
        return .imported(message: message, hasSkipped: skipped > 0)
    }

    // MARK: - 文案

    /// 导入预览弹窗正文：条目数、跳过数与三分区差异
    public static func analysisText(_ preview: ImportPreview) -> String {
        var text = "包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、\(preview.taskCount) 个任务"
        let skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
        if skipped > 0 { text += "\n跳过异常数据 \(skipped) 条" }
        if let difference = preview.difference {
            text += "\n\n差异分析"
            text += "\n日志：新增 \(difference.logs.added) · 修改 \(difference.logs.changed)" +
                " · 相同 \(difference.logs.unchanged) · 仅本机 \(difference.logs.localOnly)"
            text += "\n情绪：新增 \(difference.emotions.added) · 修改 \(difference.emotions.changed)" +
                " · 相同 \(difference.emotions.unchanged) · 仅本机 \(difference.emotions.localOnly)"
            text += "\n任务：新增 \(difference.tasks.added) · 修改 \(difference.tasks.changed)" +
                " · 相同 \(difference.tasks.unchanged) · 仅本机 \(difference.tasks.localOnly)"
            text += "\n\n差异合并会新增或更新接收数据，并保留仅本机数据；覆盖会先清空本机数据。"
        }
        return text
    }

    /// 设置页「关于」的版本串（取宿主 App Info.plist）
    public static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Flash Aero v\(version) (\(build))"
    }
}
