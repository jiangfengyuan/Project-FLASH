// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Observation

/// iOS 一级导航：对应 macOS `Module` 的一级入口（此刻 / 记录 / 回顾 / Memory / 设置），
/// 标题与 SF Symbol 与 macOS 侧栏同源。日志流、情绪、日历等次级入口在各 Tab 内推入。
enum AppTab: String, CaseIterable, Identifiable {
    case home, explore, stats, memory, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "此刻"
        case .explore: "记录"
        case .stats: "回顾"
        case .memory: "Memory"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "square.and.pencil"
        case .stats: "chart.line.uptrend.xyaxis"
        case .memory: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

/// 全局应用状态：Tab 选中 + 存储降级提示（语义与 macOS AppState 对齐）。
@Observable
final class AppState {
    var selectedTab: AppTab = .home
    /// 本地数据库回退提示；非 nil 时由 RootView 弹 alert（「我知道了」置 nil）
    var databaseFallbackMessage: String?
    /// 容器是否处于内存降级模式（持久标记，不随提示确认而清除）
    private(set) var isDatabaseInMemoryFallback = false

    /// 启动时检测数据库回退标记（App 装配层在容器创建后调用）；文案与 macOS 一致
    func checkDatabaseFallback(didFallbackToMemory: Bool) {
        guard didFallbackToMemory else { return }
        isDatabaseInMemoryFallback = true
        databaseFallbackMessage = "本地数据库暂时不可用，已进入临时内存模式，重启后数据可能丢失，建议尽快导出备份"
    }
}
