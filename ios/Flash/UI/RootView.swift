// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 根视图：底部 Tab（iPhone）承载 macOS 侧栏的一级入口，每个 Tab 自带导航栈；
/// 次级页面（日志流 / 情绪 / 日历）按 AppRoute 推入。全局搜索与首启欢迎页在此层弹出。
struct RootView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject private var settings: SettingsStore
    @Environment(IdeaReminderCenter.self) private var ideaReminders
    @Environment(\.flashRepository) private var repository

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: AppTab.home) {
                NavigationStack(path: $appState.homePath) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self, destination: routeView)
                }
            }
            Tab(AppTab.explore.title, systemImage: AppTab.explore.systemImage, value: AppTab.explore) {
                NavigationStack(path: $appState.explorePath) {
                    ExploreScreen()
                        .navigationDestination(for: AppRoute.self, destination: routeView)
                }
            }
            // 灵感提醒：未读灵感达到阈值时在记录 Tab 显示数量角标
            .badge(ideaReminders.badgeCount)
            Tab(AppTab.stats.title, systemImage: AppTab.stats.systemImage, value: AppTab.stats) {
                NavigationStack(path: $appState.statsPath) {
                    StatsScreen()
                        .navigationDestination(for: AppRoute.self, destination: routeView)
                }
            }
            Tab(AppTab.memory.title, systemImage: AppTab.memory.systemImage, value: AppTab.memory) {
                NavigationStack {
                    MemoryScreen()
                }
            }
            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: AppTab.settings) {
                NavigationStack {
                    SettingsScreen()
                }
            }
        }
        // 快速记录常驻入口（iOS 26+ 标签栏底部配件；更早系统为悬浮按钮）
        .quickCaptureEntry { appState.presentQuickCapture() }
        // 共享页面隐藏自绘大标题，标题交给系统导航栏
        .environment(\.flashUsesSystemNavigationTitle, true)
        .environment(appState.focusRouter)
        // 灵感提醒接入共享列表：未读标记与「打开即已读」
        .environment(\.flashUnreadIdeaIDs, ideaReminders.unreadIDs)
        .environment(\.flashMarkIdeaViewed, FlashMarkIdeaViewedAction { id in
            ideaReminders.markViewed(id, repository: repository, settings: settings)
        })
        // 任一写入 / 启动 / 提醒设置变化：重算未读并重排通知
        .task { refreshIdeaReminders() }
        .onChange(of: repository?.revision ?? 0) { refreshIdeaReminders() }
        .onChange(of: settings.ideaReminderEnabled) { refreshIdeaReminders() }
        .onChange(of: settings.ideaReminderFrequency) { refreshIdeaReminders() }
        .sheet(isPresented: $appState.isSearchPresented) {
            SearchScreen()
        }
        .sheet(item: $appState.quickCapture) { request in
            QuickCaptureSheet(initialCategory: request.category)
                .id(request.id)
        }
        .fullScreenCover(isPresented: welcomePresented) {
            WelcomeScreen { settings.setWelcomed() }
        }
        .alert("数据存储异常", isPresented: databaseFallbackAlertPresented) {
            Button("我知道了") { appState.databaseFallbackMessage = nil }
        } message: {
            Text(appState.databaseFallbackMessage ?? "")
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        Group {
            switch route {
            case .logFlow: LogFlowView()
            case .emotion: EmotionView()
            case .calendar: CalendarView()
            }
        }
        .background(BrandColors.pageBackground)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func refreshIdeaReminders() {
        ideaReminders.refresh(repository: repository, settings: settings)
    }

    private var welcomePresented: Binding<Bool> {
        Binding(get: { !settings.welcomed }, set: { if !$0 { settings.setWelcomed() } })
    }

    private var databaseFallbackAlertPresented: Binding<Bool> {
        Binding(
            get: { appState.databaseFallbackMessage != nil },
            set: { if !$0 { appState.databaseFallbackMessage = nil } }
        )
    }
}

/// 各 Tab 根页的全局搜索入口（导航栏右上角放大镜）
struct GlobalSearchToolbarItem: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.isSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("全局搜索")
        }
    }
}
