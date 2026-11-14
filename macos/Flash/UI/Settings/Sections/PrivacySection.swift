// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 「隐私」分组：应用锁（触控 ID 或登录密码）。
struct PrivacySection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 分组入场标记（stagger 淡入上移），由 SettingsView 驱动
    let appeared: Bool

    var body: some View {
        Section {
            AppLockToggleRow()
        } header: {
            Text("隐私")
        } footer: {
            Text("开启后，打开 Flash、离开超过 5 分钟，或电脑睡眠、锁屏后，需要用触控 ID 或登录密码解锁主窗口。Quick Capture 与菜单栏不受影响。")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: !appeared && !reduceMotion ? 6 : 0)
    }
}
