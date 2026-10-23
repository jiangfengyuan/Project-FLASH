// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import UserNotifications
import FlashCore
import FlashDesign

@main
struct FlashApp: App {
    /// 装配单一入口（与 macOS 同源：RepositoryEnvironment.makeDefault）：容器、仓储、内存降级标记
    private let assembly: RepositoryEnvironment.Assembly
    @State private var appState: AppState
    @StateObject private var settings: SettingsStore
    /// 灵感提醒：未读灵感、角标与本地通知
    @State private var ideaReminders = IdeaReminderCenter()

    init() {
        // 过期分享副本清理是纯沙箱文件 IO，移出启动同步路径后台执行（同 macOS）
        Task.detached(priority: .utility) {
            try? BackupTransfer.cleanupExpired()
        }
        let assembly = Perf.measure("StartupAssembly") { RepositoryEnvironment.makeDefault() }
        self.assembly = assembly
        let appState = AppState()
        appState.checkDatabaseFallback(didFallbackToMemory: assembly.didFallbackToMemory)
        _appState = State(initialValue: appState)
        _settings = StateObject(wrappedValue: SettingsStore())
        // App Intents 在本进程执行：注入同一仓储与应用状态（快捷指令 / 控制中心直接写库或唤起面板）
        IntentBridge.repository = assembly.repository
        IntentBridge.appState = appState
        // 通知点按（灵感提醒等）走深链；前台也展示横幅
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // 任务提醒通知上的「完成 / 稍后 10 分钟」
        TaskReminderScheduler.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(ideaReminders)
                .environment(\.flashRepository, assembly.repository)
                .environmentObject(settings)
                .preferredColorScheme(settings.themeMode.colorScheme)
                .tint(BrandColors.brandPrimary)
                // 深链：flash://capture、flash://today、flash://ideas（小组件 / 通知 / 控制中心）
                .onOpenURL { appState.handle(url: $0) }
                .task {
                    // 小组件共享快照：启动时刷新一次；App Group 不可用（未签名构建）时零成本 no-op
                    WidgetSnapshot.refresh(repository: assembly.repository)
                    #if DEBUG
                    DebugSeeder.seedIfRequested(repository: assembly.repository)
                    #endif
                    do {
                        let tasks = try Perf.measure("TasksForReminderRebuild") {
                            try assembly.repository.tasksOnly()
                        }
                        try await TaskReminderScheduler.shared.rebuild(tasks)
                    } catch TaskReminderError.permissionDenied {
                        // 用户拒绝通知权限只影响系统提醒，不误报存储故障
                    } catch {
                        appState.databaseFallbackMessage =
                            "无法读取任务并恢复系统提醒；本地内容仍然安全，请稍后重启应用重试"
                    }
                }
        }
        .modelContainer(assembly.container)
    }
}
