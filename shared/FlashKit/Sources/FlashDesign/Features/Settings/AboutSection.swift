// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 「关于 Flash」分组：版本号 + 无云端账号说明
public struct AboutSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 形如 "Flash Aero v1.0 (1)" 的版本串，由 SettingsView 从 Bundle 读取
    public let version: String
    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    public let appeared: Bool

    public init(version: String, appeared: Bool) {
        self.version = version
        self.appeared = appeared
    }

    public var body: some View {
        Section("关于 Flash") {
            LabeledContent {
                Text(version)
            } label: {
                SettingsRowLabel(title: "版本", systemImage: "info.circle", color: .secondary)
            }
            Label("无云端账号，备份与传输由你主动发起。", systemImage: "lock.shield")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: !appeared && !reduceMotion ? 6 : 0)
    }
}
