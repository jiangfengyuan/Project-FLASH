import SwiftUI

enum Module: String, CaseIterable, Identifiable {
    case home, explore, logflow, emotion, calendar, stats, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .explore: "探索"
        case .logflow: "记录流"
        case .emotion: "情绪"
        case .calendar: "日历"
        case .stats: "统计"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "safari"
        case .logflow: "list.bullet.rectangle"
        case .emotion: "face.smiling"
        case .calendar: "calendar"
        case .stats: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}

/// 全局应用状态：侧栏选中 + 菜单命令路由（spec §4）。
@Observable
final class AppState {
    var selectedModule: Module = .home
    /// 菜单「新建记录」⌘N → token 递增，Home/Explore 监听并聚焦输入框
    private(set) var newLogRequestToken = 0
    /// 菜单「导出备份…」⇧⌘E → token 递增，Settings 监听并弹导出面板
    private(set) var exportRequestToken = 0

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
}
