// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 根视图：底部 Tab（iPhone）承载 macOS 侧栏的一级入口；
/// 尚未移植的模块显示占位页，随里程碑逐个替换。
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    content(for: tab)
                }
            }
        }
        .alert("数据存储异常", isPresented: databaseFallbackAlertPresented) {
            Button("我知道了") { appState.databaseFallbackMessage = nil }
        } message: {
            Text(appState.databaseFallbackMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            NavigationStack { HomeView() }
        case .explore, .stats, .memory, .settings:
            ModulePlaceholderView(tab: tab)
        }
    }

    private var databaseFallbackAlertPresented: Binding<Bool> {
        Binding(
            get: { appState.databaseFallbackMessage != nil },
            set: { if !$0 { appState.databaseFallbackMessage = nil } }
        )
    }
}
