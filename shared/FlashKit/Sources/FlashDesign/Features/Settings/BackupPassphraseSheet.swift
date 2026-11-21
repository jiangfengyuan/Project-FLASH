// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 导出前的加密选择（默认加密）与导入加密备份时的口令输入，iOS 与 macOS 共用。
/// 口令只在本视图与一次导出/导入调用中存在，Flash 不保存口令。
public struct BackupPassphraseSheet: View {
    public enum Mode {
        /// 导出 / 分享：`nil` 表示用户选择不加密
        case export(onConfirm: (String?) -> Void)
        case exportWithFormat(onConfirm: (BackupExportFormat, String?) -> Void)
        /// 导入加密备份：`error` 为上次尝试的错误文案（口令错误等）
        case unlock(error: String?, onSubmit: (String) -> Void)
    }

    private let mode: Mode
    private let onCancel: () -> Void
    @State private var encrypt = true
    @State private var format = BackupExportFormat.fullLibrary
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var problem: String? = nil
    @FocusState private var focused: Bool

    public init(mode: Mode, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                switch mode {
                case .export: exportContent
                case .exportWithFormat:
                    formatSection
                    exportContent
                case .unlock(let error, _): unlockContent(error: error)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isExport ? L("导出备份") : L("加密备份"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isExport ? L("继续") : L("解密")) { submit() }
                        .disabled(!isExport || encrypt ? passphrase.isEmpty : false)
                }
            }
        }
        .onAppear { focused = true }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: offersFormatChoice ? 510 : 340)
        #endif
    }

    private var isExport: Bool {
        if case .unlock = mode { return false }
        return true
    }

    private var offersFormatChoice: Bool {
        if case .exportWithFormat = mode { return true }
        return false
    }

    private var formatSection: some View {
        Section {
            Picker("导出内容", selection: $format) {
                Text("完整资料库（v4）").tag(BackupExportFormat.fullLibrary)
                Text("兼容正文（v2）").tag(BackupExportFormat.compatibleRecords)
            }
        } footer: {
            if format == .compatibleRecords {
                Text("仅导出当前日志、情绪和任务，可在 Android 或 HarmonyOS 导入。此文件不含自由标签及其关联、已保存筛选、灵感提醒、回忆偏好、自动标签设置和回收站。")
            } else {
                Text("完整备份包含正文、资料库设置和回收站，恢复时需要支持 v4 的 Flash。")
            }
        }
    }

    @ViewBuilder
    private var exportContent: some View {
        Section {
            Toggle("用口令加密备份（推荐）", isOn: $encrypt.animation())
        } footer: {
            Text(encrypt
                 ? L("没有口令的人无法读取或改动备份内容。Flash 不保存口令，忘记后无法恢复。")
                 : L("不加密的备份是明文 JSON，任何拿到文件的人都能读取全部日志、情绪和任务。仅保存或分享给可信设备或联系人。"))
        }
        if encrypt {
            Section {
                SecureField("口令（至少 8 个字符）", text: $passphrase)
                    .textContentType(.newPassword)
                    .focused($focused)
                SecureField("再次输入口令", text: $confirmation)
                    .textContentType(.newPassword)
                    .onSubmit(submit)
            } footer: {
                if let problem { Text(problem).foregroundStyle(.red) }
            }
        }
    }

    @ViewBuilder
    private func unlockContent(error: String?) -> some View {
        Section {
            SecureField("口令", text: $passphrase)
                .textContentType(.password)
                .focused($focused)
                .onSubmit(submit)
        } header: {
            Text("这是加密备份，请输入导出时设置的口令")
        } footer: {
            if let error { Text(error).foregroundStyle(.red) }
        }
    }

    private func submit() {
        switch mode {
        case .export(let onConfirm):
            confirmExport(onConfirm)
        case .exportWithFormat(let onConfirm):
            confirmExport { onConfirm(format, $0) }
        case .unlock(_, let onSubmit):
            guard !passphrase.isEmpty else { return }
            onSubmit(passphrase)
        }
    }

    private func confirmExport(_ onConfirm: (String?) -> Void) {
        guard encrypt else { onConfirm(nil); return }
        do {
            try BackupEncryption.validateExportPassphrase(passphrase)
        } catch let error as BackupError {
            problem = error.userMessage
            return
        } catch {
            return
        }
        guard passphrase == confirmation else {
            problem = L("两次输入的口令不一致")
            return
        }
        onConfirm(passphrase)
    }
}
