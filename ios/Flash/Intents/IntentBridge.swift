// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import FlashCore

/// App Intents 与 App 装配的连接点：intent 在 App 进程内执行（快捷指令 / Siri / 控制中心
/// 拉起 App 时 FlashApp.init 先运行并注入），从这里取同一个仓储与应用状态，写路径不分叉。
@MainActor
enum IntentBridge {
    static var repository: FlashRepository?
    static var appState: AppState?
}
