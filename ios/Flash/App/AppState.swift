// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
import FlashCore

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

/// Tab 内推入的次级页面（对应 macOS 侧栏的次级入口）
enum AppRoute: Hashable {
    case logFlow
    case emotion
    case calendar

    var title: String {
        switch self {
        case .logFlow: "日志流"
        case .emotion: "情绪"
        case .calendar: "日历"
        }
    }
}

/// 快速记录弹层请求（sheet(item:) 承载）：携带外部指定的初始类型
struct QuickCaptureRequest: Identifiable, Equatable {
    let id = UUID()
    /// nil = 沿用草稿类型或默认灵感
    var category: Category?
}

/// 全局应用状态：Tab 选中、各 Tab 导航路径、跨模块定位、全局弹层与存储降级提示
/// （语义与 macOS AppState 对齐）。
@Observable
final class AppState {
    var selectedTab: AppTab = .home
    /// 各 Tab 的导航栈（次级页面推入）
    var homePath: [AppRoute] = []
    var explorePath: [AppRoute] = []
    var statsPath: [AppRoute] = []

    /// 全局搜索弹层（各 Tab 根页工具栏的放大镜唤起）
    var isSearchPresented = false
    /// 快速记录弹层（常驻入口 / flash://capture / 快捷指令 / 控制中心）
    var quickCapture: QuickCaptureRequest? = nil
    /// 记录页筛选请求（flash://ideas、灵感提醒）：记录页出现时消费
    var exploreFilterRequest: ExploreFilter? = nil

    /// 跨模块定位：共享视图（日历「查看灵感」等）与 iOS 页面共用同一路由
    let focusRouter = FocusRouter()

    /// 本地数据库回退提示；非 nil 时由 RootView 弹 alert（「我知道了」置 nil）
    var databaseFallbackMessage: String?
    /// 容器是否处于内存降级模式（持久标记，不随提示确认而清除）
    private(set) var isDatabaseInMemoryFallback = false

    init() {
        // 定位先切 Tab / 推入目标页，再由目标页 onAppear/onChange 消费载荷
        focusRouter.onRequest = { [weak self] destination in
            self?.route(to: destination)
        }
    }

    /// 定位目标 → Tab 与导航栈：
    /// 记录/灵感 → 记录页（打开编辑弹层）；情绪 → 此刻页推入情绪；任务 → 回顾页推入日历
    func route(to destination: FocusDestination) {
        isSearchPresented = false
        switch destination {
        case .log:
            explorePath = []
            selectedTab = .explore
        case .emotion:
            homePath = [.emotion]
            selectedTab = .home
        case .task:
            statsPath = [.calendar]
            selectedTab = .stats
        }
    }

    /// 在当前 Tab 推入次级页面（此刻「+ 新建 → 情绪」等）
    func push(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .explore: explorePath.append(route)
        case .stats: statsPath.append(route)
        case .memory, .settings:
            homePath = [route]
            selectedTab = .home
        }
    }

    /// 唤起快速记录（已打开时只更新类型，不重复弹出）
    func presentQuickCapture(category: Category? = nil) {
        isSearchPresented = false
        quickCapture = QuickCaptureRequest(category: category)
    }

    /// 深链：
    /// - flash://capture[?category=idea|log] → 快速记录
    /// - flash://today → 此刻
    /// - flash://ideas → 记录页「灵感」筛选（灵感提醒通知 / 小组件）
    /// 返回是否识别；未知链接忽略
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "flash", let host = url.host() else { return false }
        switch host {
        case "capture":
            let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "category" })?.value
            presentQuickCapture(category: value.flatMap(Category.init(rawValue:)))
        case "today":
            homePath = []
            selectedTab = .home
        case "ideas":
            explorePath = []
            exploreFilterRequest = .idea
            selectedTab = .explore
        default:
            return false
        }
        return true
    }

    /// 启动时检测数据库回退标记（App 装配层在容器创建后调用）；文案与 macOS 一致
    func checkDatabaseFallback(didFallbackToMemory: Bool) {
        guard didFallbackToMemory else { return }
        isDatabaseInMemoryFallback = true
        databaseFallbackMessage = "本地数据库暂时不可用，已进入临时内存模式，重启后数据可能丢失，建议尽快导出备份"
    }
}
