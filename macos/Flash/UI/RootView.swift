// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 225, ideal: 240, max: 350)
        } detail: {
            detailView(for: appState.selectedModule)
                .id(appState.selectedModule)
                .transition(pageTransition)
                .animation(pageAnimation, value: appState.selectedModule)
                .navigationTitle(appState.selectedModule.title)
                .frame(minWidth: 560, minHeight: 480)
        }
        .frame(minWidth: 960, minHeight: 640)
        .alert("数据存储异常", isPresented: databaseFallbackAlertPresented) {
            Button("我知道了") { appState.databaseFallbackMessage = nil }
        } message: {
            Text(appState.databaseFallbackMessage ?? "")
        }
    }

    /// SwiftData 回退内存库时 AppState 置入提示文案，展示后由「我知道了」置 nil
    private var databaseFallbackAlertPresented: Binding<Bool> {
        Binding(
            get: { appState.databaseFallbackMessage != nil },
            set: { if !$0 { appState.databaseFallbackMessage = nil } }
        )
    }

    /// 页面过渡：淡入淡出 + 极轻上移；减弱动态时仅淡入淡出（FlashMotion .appear）
    private var pageTransition: AnyTransition {
        .appear(reduceMotion: reduceMotion)
    }

    /// 页面切换曲线：正常用标准 easeOut；减弱动态时保底极短淡变（不产生位移）
    private var pageAnimation: Animation? {
        reduceMotion ? Motion.reducedFade(true) : Motion.softOut()
    }

    @ViewBuilder
    private func detailView(for module: Module) -> some View {
        switch module {
        case .home: HomeView()
        case .explore: ExploreView()
        case .logflow: LogFlowView()
        case .emotion: EmotionView()
        case .calendar: CalendarView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }
}
