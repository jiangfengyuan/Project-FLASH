// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppIntents

/// 控制中心「快速记录」控件的动作。同时编入 App 与小组件扩展：扩展用它声明控件，
/// openAppWhenRun 让系统在 App 进程内执行 perform（扩展无法把 App 带到前台）。
/// 系统 OpenURLIntent 不能直接作控件动作（扩展里没有它的元数据，点按报「without linkAction」），
/// 从 perform 返回它也不会被打开，故由 App 注入 presentCapture 直接弹出面板。
struct QuickCaptureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Flash 快速记录"
    static let description = IntentDescription("打开 Flash 的快速记录面板。")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    /// App 启动时注入；扩展进程里为 nil（perform 只在 App 进程执行）
    @MainActor static var presentCapture: (() -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.presentCapture?()
        return .result()
    }
}
