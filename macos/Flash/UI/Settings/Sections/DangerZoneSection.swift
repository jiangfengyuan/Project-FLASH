// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 「危险操作」分组：清空全部数据（确认 alert 由 SettingsView 承载）。
/// 视觉独立：红色语义组头 + 说明文字 + destructive 按钮，与普通操作隔离。
struct DangerZoneSection: View {
    /// 导入/导出进行中或 LAN 传输非空闲时禁用
    let isDisabled: Bool
    let onClear: () -> Void

    var body: some View {
        Section {
            Text("将删除本机全部日志、灵感、情绪与任务，清空后无法撤销，建议先导出备份。")
                .font(Typography.caption).foregroundStyle(.secondary)
            Button(role: .destructive, action: onClear) {
                SettingsRowLabel(title: "清空全部数据…", systemImage: "trash", color: .red)
            }
        } header: {
            Label("危险操作", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Color(nsColor: .systemRed))
        }
        .disabled(isDisabled)
    }
}
