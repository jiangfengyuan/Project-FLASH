// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import FlashCore
import FlashDesign

/// 轻 AppDelegate（Quick Capture PRD §13/§14 配套）：
/// - 主窗口关闭后 App 不退出（配合 MenuBarExtra 驻留，全局热键才可用）；
/// - 启动装配完成后（事件循环就绪）注册全局热键。
/// 窗口装配仍在 FlashApp 的 SwiftUI Scene 内，本类不含任何 WindowGroup/MenuBarExtra 逻辑。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        QuickCaptureController.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
