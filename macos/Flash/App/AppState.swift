// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Observation
import FlashCore
import FlashDesign

enum Module: String, CaseIterable, Identifiable {
    case home, explore, logflow, emotion, calendar, stats, memory, settings

    var id: String { rawValue }

    /// 一级导航：此刻 / 记录 / 回顾 / 设置；
    /// 情绪、日历、日志流、Memory 为次级入口（侧栏分组展示）
    var title: String {
        switch self {
        case .home: "此刻"
        case .explore: "记录"
        case .logflow: "日志流"
        case .emotion: "情绪"
        case .calendar: "日历"
        case .stats: "回顾"
        case .memory: "Memory"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "square.and.pencil"
        case .logflow: "list.bullet.rectangle"
        case .emotion: "face.smiling"
        case .calendar: "calendar"
        case .stats: "chart.line.uptrend.xyaxis"
        // sparkles 已被菜单栏伴侣（MenuBarExtra）占用；周报是「回看过去一周」，
        // 用回溯语义图标（PRD §32 建议方向之一）
        case .memory: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

/// 跨模块定位目标（全局搜索跳转 / 日历「查看灵感」）：目标模块 + 可选载荷。
/// 消费方按载荷类型取用：记录页取 logID 打开编辑弹层；日历页取 taskDate 选中日期；
/// 情绪记录无详情编辑态，仅切换模块即可。
struct FocusTarget: Equatable {
    let module: Module
    /// 记录/灵感 id：记录页打开该记录的编辑弹层
    var logID: String? = nil
    /// 任务的日历日（yyyy-MM-dd）：日历页选中并翻到该日期
    var taskDate: String? = nil

    static func log(_ id: String) -> FocusTarget { FocusTarget(module: .explore, logID: id) }
    static var emotion: FocusTarget { FocusTarget(module: .emotion) }
    static func task(on date: String?) -> FocusTarget { FocusTarget(module: .calendar, taskDate: date) }
}

/// 全局应用状态：侧栏选中 + 菜单命令路由（spec §4）。
@Observable
final class AppState {
    var selectedModule: Module = .home
    /// 菜单「新建记录」⌘N → token 递增，Home/Explore 监听并聚焦输入框
    private(set) var newLogRequestToken = 0
    private(set) var handledNewLogToken = 0
    /// 菜单「导出备份…」⇧⌘E → token 递增，Settings 监听并弹导出面板
    private(set) var exportRequestToken = 0
    private(set) var handledExportToken = 0
    /// 菜单「搜索」⌘K → 唤起 RootView 层的全局搜索浮层（Spotlight 风格）
    var isGlobalSearchPresented = false
    /// 跨模块定位：token + 载荷模式（同 requestSearch 旧 token 的消费语义），
    /// 目标页 onAppear 兜底 + onChange 消费，handled token 与请求 token 同存于此，
    /// 视图重建后不会归零，保证不回放旧 token。
    private(set) var focusTarget: FocusTarget? = nil
    private(set) var focusRequestToken = 0
    private(set) var handledFocusToken = 0
    /// 本地数据库回退提示；非 nil 时由 RootView 弹 alert。
    /// 持久化容器创建失败、降级为内存模式时本次运行数据不持久，必须告知用户。
    /// setter 开放：RootView「我知道了」直接置 nil 清除（亦可用 clearDatabaseFallbackMessage()）。
    var databaseFallbackMessage: String?
    /// 容器是否处于内存降级模式（持久标记，不随 databaseFallbackMessage 的确认而清除）。
    /// RootView 的 alert 可关闭，但菜单栏伴侣等场景的持久警示依赖此标记，
    /// 降级期间任何写入都只落在易失内存库。
    private(set) var isDatabaseInMemoryFallback = false

    func requestNewLog() {
        if selectedModule != .home && selectedModule != .explore {
            selectedModule = .home
        }
        newLogRequestToken += 1
    }

    func requestExport() {
        selectedModule = .settings
        exportRequestToken += 1
    }

    /// ⌘K 全局搜索：唤起浮层（不切模块；Explore 页内搜索是独立能力，不再响应 ⌘K）
    func requestSearch() {
        isGlobalSearchPresented = true
    }

    /// 跨模块定位：先切模块再发 token，目标页消费载荷后清除
    func requestFocus(_ target: FocusTarget) {
        selectedModule = target.module
        focusTarget = target
        focusRequestToken += 1
    }

    /// 目标页消费一次：token 未消费过才返回载荷；无论载荷是否适用都标记已处理，
    /// 避免不适用载荷（如情绪跳转无 logID）滞留后被后续页面误消费
    @discardableResult
    func consumeFocusTarget() -> FocusTarget? {
        guard focusRequestToken != handledFocusToken else { return nil }
        handledFocusToken = focusRequestToken
        defer { focusTarget = nil }
        return focusTarget
    }

    func markNewLogHandled() { handledNewLogToken = newLogRequestToken }
    func markExportHandled() { handledExportToken = exportRequestToken }

    /// 启动时检测数据库回退标记（由 App 装配层在容器创建后调用，
    /// 标记来自 FlashDatabase.makeContainerWithFallback / RepositoryEnvironment.makeDefault）。
    /// 已降级内存模式时设置中文提示；未回退时保持 nil。
    func checkDatabaseFallback(didFallbackToMemory: Bool) {
        guard didFallbackToMemory else { return }
        isDatabaseInMemoryFallback = true
        databaseFallbackMessage = "本地数据库暂时不可用，已进入临时内存模式，重启后数据可能丢失，建议尽快导出备份"
    }

    /// 用户确认后清除回退提示
    func clearDatabaseFallbackMessage() {
        databaseFallbackMessage = nil
    }
}
