import Observation

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
    /// 菜单「搜索」⌘K → 切到首页 + token 递增，Home 监听并聚焦搜索框
    private(set) var searchRequestToken = 0
    /// 本地数据库回退提示；非 nil 时由 RootView 弹 alert。
    /// 持久化容器创建失败、降级为内存模式时本次运行数据不持久，必须告知用户。
    /// setter 开放：RootView「我知道了」直接置 nil 清除（亦可用 clearDatabaseFallbackMessage()）。
    var databaseFallbackMessage: String?

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

    /// ⌘K 搜索：先切到首页再递增 token。
    /// 若已在首页，HomeView 的 onChange 直接消费；不在首页时本视图随切换重建，
    /// onAppear 兜底消费一次，handledSearchToken 机制保证不回放旧 token。
    func requestSearch() {
        selectedModule = .home
        searchRequestToken += 1
    }

    /// 启动时检测数据库回退标记（由 App 装配层在容器创建后调用，
    /// 标记来自 FlashDatabase.makeContainerWithFallback / RepositoryEnvironment.makeDefault）。
    /// 已降级内存模式时设置中文提示；未回退时保持 nil。
    func checkDatabaseFallback(didFallbackToMemory: Bool) {
        guard didFallbackToMemory else { return }
        databaseFallbackMessage = "本地数据库暂时不可用，已进入临时内存模式，重启后数据可能丢失，建议尽快导出备份"
    }

    /// 用户确认后清除回退提示
    func clearDatabaseFallbackMessage() {
        databaseFallbackMessage = nil
    }
}
