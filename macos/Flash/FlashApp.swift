// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

@main
struct FlashApp: App {
    /// 装配单一入口（债务 A6）：容器、仓储、内存降级标记三者同源
    private let assembly: RepositoryEnvironment.Assembly
    @State private var appState: AppState
    @StateObject private var settings = SettingsStore()

    init() {
        let assembly = RepositoryEnvironment.makeDefault()
        self.assembly = assembly
        let appState = AppState()
        appState.checkDatabaseFallback(didFallbackToMemory: assembly.didFallbackToMemory)
        _appState = State(initialValue: appState)
    }

    var body: some Scene {
        // 显式 id：MenuBarExtra 通过 openWindow(id: "main") 唤起主窗口
        WindowGroup(id: "main") {
            Group {
                if settings.welcomed {
                    RootView()
                } else {
                    WelcomeView {
                        settings.setWelcomed()
                    }
                }
            }
            .environment(appState)
            .environment(\.flashRepository, assembly.repository)
            .environmentObject(settings)
            .preferredColorScheme(colorScheme(for: settings.themeMode))
        }
        .modelContainer(assembly.container)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 760)
        .commands {
            // 单 WindowGroup、无 Settings scene 时系统不会生成「设置 ⌘,」，手动补
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { appState.selectedModule = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
            // .importExport 锚点仅在文档型应用存在，非文档型 WindowGroup 下挂其上的命令组会被系统静默丢弃；
            // 「导出备份…」改挂 .newItem 组内（快捷键 ⇧⌘E 不变）
            CommandGroup(replacing: .newItem) {
                Button("新建记录") { appState.requestNewLog() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("导出备份…") { appState.requestExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
            // ⌘K 搜索：token 递增，各页面监听并聚焦搜索框
            CommandGroup(after: .sidebar) {
                Button("搜索") { appState.requestSearch() }
                    .keyboardShortcut("k", modifiers: .command)
            }
            // 模块切换 ⌘1…⌘6（顺序同侧栏；设置已有 ⌘,，不重复占用）
            CommandMenu("模块") {
                Button("首页") { appState.selectedModule = .home }
                    .keyboardShortcut("1", modifiers: .command)
                Button("探索") { appState.selectedModule = .explore }
                    .keyboardShortcut("2", modifiers: .command)
                Button("记录流") { appState.selectedModule = .logflow }
                    .keyboardShortcut("3", modifiers: .command)
                Button("情绪") { appState.selectedModule = .emotion }
                    .keyboardShortcut("4", modifiers: .command)
                Button("日历") { appState.selectedModule = .calendar }
                    .keyboardShortcut("5", modifiers: .command)
                Button("统计") { appState.selectedModule = .stats }
                    .keyboardShortcut("6", modifiers: .command)
            }
        }

        // V1.1 Menu Bar Companion（PRD §26）：窗口式面板，点击外部自动关闭（系统默认行为）
        MenuBarExtra("Flash", systemImage: "sparkles") {
            MenuBarCompanionView()
                .environment(appState)
                .environment(\.flashRepository, assembly.repository)
                .environmentObject(settings)
                .preferredColorScheme(colorScheme(for: settings.themeMode))
        }
        .menuBarExtraStyle(.window)
        .modelContainer(assembly.container)
    }

    private func colorScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
