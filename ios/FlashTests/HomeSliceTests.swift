// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import SwiftData
import Testing
import FlashCore
@testable import Flash

/// iOS 此刻页切片：Tab 与 macOS 一级入口对齐 + 快速记录 → 仓储 → 视图模型的端到端链路
@MainActor
@Suite("iOS 此刻切片")
struct HomeSliceTests {
    @Test func tabsMirrorMacOSPrimaryModules() {
        #expect(AppTab.allCases.map(\.title) == ["此刻", "记录", "回顾", "Memory", "设置"])
        #expect(AppTab.home.systemImage == "house")
        #expect(AppTab.memory.systemImage == "clock.arrow.circlepath")
    }

    @Test func databaseFallbackRaisesAlertMessage() {
        let state = AppState()
        state.checkDatabaseFallback(didFallbackToMemory: false)
        #expect(state.databaseFallbackMessage == nil)
        state.checkDatabaseFallback(didFallbackToMemory: true)
        #expect(state.isDatabaseInMemoryFallback)
        #expect(state.databaseFallbackMessage?.isEmpty == false)
    }

    @Test func captureFlowsIntoTodayOverviewAndRecentList() throws {
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        let before = repository.revision
        #expect(try QuickCaptureCommit.commit("通勤路上想到的点子!!", as: .idea, repository: repository)
                == .saved(toast: "✓ 已保存到灵感"))
        #expect(try QuickCaptureCommit.commit("午饭吃了面", as: .log, repository: repository)
                == .saved(toast: "✓ 已保存到日志"))
        #expect(repository.revision == before + 2)

        let viewModel = HomeViewModel()
        viewModel.update(logs: try repository.allLogs(), emotions: try repository.allEmotions())
        #expect(viewModel.todayRecordCount == 2)
        #expect(viewModel.todayIdeaCount == 1)
        #expect(viewModel.recentLogs.map(\.content).contains("通勤路上想到的点子!!"))

        let idea = try #require(viewModel.recentLogs.first { $0.category == .idea })
        try repository.setLogFavorite(id: idea.id, true)
        try repository.deleteLog(id: idea.id)
        viewModel.update(logs: try repository.allLogs(), emotions: try repository.allEmotions())
        #expect(viewModel.todayRecordCount == 1)
    }
}
