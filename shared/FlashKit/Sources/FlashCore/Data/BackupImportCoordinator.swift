// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 备份导入/导出流水线（macOS 设置页与 iOS 设置页共用；平台只负责选文件与呈现）。
///
/// 导入：读文件（明文 50 MB、加密信封 72 MB 上限）→ 加密备份先凭口令解密 →
/// 严格解析 v2 或恢复解析 → 与本机快照做差异分析 → 预览 →
/// 合并或覆盖写库（覆盖前 TOCTOU 重校验）→ 重建系统提醒。
/// 序列化、解析与差异分析在后台执行；写库经 `@MainActor` 的 FlashRepository。
public enum BackupImportCoordinator {
    /// Detached work must not outlive cancellation as a successful preview.
    /// JSONSerialization itself has no interruption hook; discard its result
    /// if cancellation arrives during that bounded synchronous operation.
    private static func background<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let value = try operation()
            try Task.checkCancellation()
            return value
        }
        return try await withTaskCancellationHandler {
            let value = try await worker.value
            try Task.checkCancellation()
            return value
        } onCancel: {
            worker.cancel()
        }
    }
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

    /// 严格 v2 导出 JSON（后台序列化）。临时存储的快照一律拒绝：
    /// 它不是完整备份，日后被当作备份覆盖导入会抹掉真实数据（F-07）。
    /// 给出 `passphrase` 时把校验过的明文包进 flash-backup-enc-v1 信封；nil 为明文导出，字节不变。
    public static func exportJSON(snapshot: FlashSnapshot, appVersion: String,
                                  passphrase: String? = nil) async throws -> String {
        guard !snapshot.isFromTemporaryStore else { throw BackupError.temporaryStore }
        if let passphrase { try BackupEncryption.validateExportPassphrase(passphrase) }
        return try await background {
            let json = try LibraryBackup.export(snapshot, appVersion: appVersion)
            guard let passphrase else { return json }
            return try BackupEncryption.encrypt(json, passphrase: passphrase)
        }
    }

    /// 导出文件的默认名：加密备份带 `-encrypted`，扩展名保持 `.json` 以便各端选择器识别
    public static func exportFileName(encrypted: Bool) -> String {
        "flash-backup-\(DateFormatting.today())\(encrypted ? "-encrypted" : "").json"
    }

    // MARK: - 预览

    /// 从用户选择的文件生成导入预览。加密备份抛出 `BackupError.encrypted`：
    /// 调用方应改用 `readBackupText` 保留文本，取得口令后调用 `preview(text:…)`。
    public static func preview(fileAt url: URL, recovery: Bool,
                               against snapshot: FlashSnapshot) async throws -> ImportPreview {
        let text = try await readBackupText(fileAt: url)
        return try await preview(text: text, recovery: recovery, passphrase: nil, against: snapshot)
    }

    /// 先查大小再流式限额读入（加密信封上限 72 MB；明文超过 50 MB 在解析时拒绝）。
    /// 读出的文本可在输入口令期间保留，无需再次访问安全作用域文件。
    public static func readBackupText(fileAt url: URL) async throws -> String {
        try await background {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize, size > BackupEncryption.maxEnvelopeBytes {
                throw BackupError.fileTooLarge
            }
            return try BackupService.readJSON(from: url, maxBytes: BackupEncryption.maxEnvelopeBytes)
        }
    }

    /// 文本 → 预览。明文 v1/v2 行为不变；加密备份缺口令时抛 `.encrypted`，
    /// 口令错误抛 `.encryptedAuthenticationFailed`（可直接重试，不必重选文件）。
    /// 解出的明文只按 v2 解析，不递归解密嵌套信封。
    public static func preview(text: String, recovery: Bool, passphrase: String?,
                               against snapshot: FlashSnapshot) async throws -> ImportPreview {
        try await background {
            analyzed(try parseBackupText(text, recovery: recovery, passphrase: passphrase), against: snapshot)
        }
    }

    static func parseBackupText(_ text: String, recovery: Bool, passphrase: String?) throws -> ImportPreview {
        func parse(_ json: String) throws -> ImportPreview {
            recovery ? try BackupService.parseRecovery(json) : try BackupService.parseStrict(json)
        }
        let isOversized = text.utf8.count > BackupService.maxFileBytes
        if isOversized {
            // 明文备份不可能超过 50 MB；只有加密信封才继续
            guard BackupEncryption.isEnvelope(text) else { throw BackupError.fileTooLarge }
        } else {
            do {
                return try parse(text)
            } catch BackupError.encrypted {
                // 加密信封：继续走解密
            }
        }
        guard let passphrase else { throw BackupError.encrypted }
        let plaintext = try BackupEncryption.decrypt(text, passphrase: passphrase)
        do {
            return try parse(plaintext)
        } catch BackupError.encrypted {
            throw BackupError.contract("/version")
        }
    }

    /// 从局域网接收的 JSON 生成导入预览（只走严格 v2）
    public static func preview(json: String, against snapshot: FlashSnapshot) async throws -> ImportPreview {
        try await background {
            analyzed(try BackupService.parseStrict(json), against: snapshot)
        }
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
        // The following main-actor mutation is a synchronous atomic commit.
        // Reject cancellation before that boundary, never report it as an
        // undone import after a successful database commit.
        try Task.checkCancellation()
        // 写进临时存储的数据退出即丢，随后的提醒重建还会按临时库撤掉真实提醒（F-07）
        guard !repository.isTemporaryStore else { throw BackupError.temporaryStore }
        if overwrite {
            let current = try repository.snapshot()
            guard previewSnapshot == current else {
                return .changedSincePreview(preview: analyzed(preview, against: current), snapshot: current)
            }
            try repository.replaceAll(logs: preview.logs, emotions: preview.emotions, tasks: preview.tasks, library: preview.library.map { var v = $0; v.remindersNeedConfirmation = v != PersonalLibrary(); return v } ?? .init(), trash: preview.trash, preferences: preview.preferences ?? .init(), automaticTags: preview.automaticTags)
        } else {
            try repository.mergeAll(logs: preview.logs, emotions: preview.emotions, tasks: preview.tasks, library: preview.library, trash: preview.trash, preferences: preview.preferences, automaticTags: preview.automaticTags)
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
        var message = L("已导入 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、\(preview.taskCount) 个任务")
        if skipped > 0 { message += L("（跳过异常数据 \(skipped) 条）") }
        return .imported(message: message, hasSkipped: skipped > 0)
    }

    // MARK: - 文案

    /// 导入预览弹窗正文：条目数、跳过数与三分区差异
    public static func analysisText(_ preview: ImportPreview) -> String {
        var text = L("包含 \(preview.logCount) 条日志、\(preview.emotionCount) 条情绪、\(preview.taskCount) 个任务")
        text += "\n" + L("回收站") + ": \(preview.trash.count)"
        if preview.preferences == nil { text += "\n" + L("覆盖旧版备份将清除本机回收站与本地智能设置") }
        if let library = preview.library {
            text += "\n" + L("自由标签") + ": \(library.tags.count) · " + L("已保存筛选") + ": \(library.filters.count)"
            text += "\n" + L("导入的灵感提醒需要确认后启用")
        } else {
            text += "\n" + L("覆盖旧版备份将清除本机自由标签、保存筛选与灵感提醒配置")
        }
        let skipped = preview.skippedLogs + preview.skippedEmotions + preview.skippedTasks
        if skipped > 0 { text += L("\n跳过异常数据 \(skipped) 条") }
        if let difference = preview.difference {
            text += L("\n\n差异分析")
            text += L("\n日志：新增 \(difference.logs.added) · 修改 \(difference.logs.changed)") +
                L(" · 相同 \(difference.logs.unchanged) · 仅本机 \(difference.logs.localOnly)")
            text += L("\n情绪：新增 \(difference.emotions.added) · 修改 \(difference.emotions.changed)") +
                L(" · 相同 \(difference.emotions.unchanged) · 仅本机 \(difference.emotions.localOnly)")
            text += L("\n任务：新增 \(difference.tasks.added) · 修改 \(difference.tasks.changed)") +
                L(" · 相同 \(difference.tasks.unchanged) · 仅本机 \(difference.tasks.localOnly)")
            text += L("\n\n差异合并会新增或更新接收数据，并保留仅本机数据；覆盖会先清空本机数据。")
        }
        return text
    }

    /// 设置页「关于」的版本串（取宿主 App Info.plist）
    public static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Flash Paper \(version) Alpha \(build)"
    }
}
