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
        /// 导入加密备份：`error` 为上次尝试的错误文案（口令错误等）
        case unlock(error: String?, onSubmit: (String) -> Void)
    }

    private let mode: Mode
    private let onCancel: () -> Void
    @State private var encrypt = true
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
        .frame(minWidth: 420, minHeight: 340)
        #endif
    }

    private var isExport: Bool {
        if case .export = mode { return true }
        return false
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
        case .unlock(_, let onSubmit):
            guard !passphrase.isEmpty else { return }
            onSubmit(passphrase)
        }
    }
}
