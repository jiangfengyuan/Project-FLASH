// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 回顾页（iOS 外壳）：共享 StatsView（趋势 / 日历分段），标题交给系统导航栏；
/// Memory 周报不再单占 Tab，由工具栏入口推入
struct StatsScreen: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StatsView()
            .navigationTitle("回顾")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.statsPath.append(.memory)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("本周 Memory")
                }
                GlobalSearchToolbarItem()
            }
    }
}
