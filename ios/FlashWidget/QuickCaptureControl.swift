// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppIntents
import SwiftUI
import WidgetKit

/// 控制中心 / 锁屏 / 操作按钮「快速记录」控件（iOS 版全局热键）：
/// 经系统 OpenURLIntent 打开 flash://capture，由 App 的深链处理弹出快速记录面板。
struct QuickCaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.flash.app.ios.quickCapture") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "flash://capture")!)) {
                Label("记一闪", systemImage: "sparkle")
            }
        }
        .displayName("Flash 快速记录")
        .description("打开 Flash 的快速记录面板。")
    }
}
