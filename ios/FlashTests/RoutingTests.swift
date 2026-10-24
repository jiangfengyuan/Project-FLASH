// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import FlashCore
@testable import Flash

/// 跨 Tab 定位：FocusRouter 请求先切 Tab / 推入目标页，再由目标页消费载荷
@Suite("iOS 跨模块定位")
struct RoutingTests {
    @Test func logRequestOpensExploreAndClosesSearch() {
        let state = AppState()
        state.isSearchPresented = true
        state.explorePath = [.logFlow]
        state.focusRouter.request(.log("abc"))
        #expect(state.selectedTab == .explore)
        #expect(state.explorePath.isEmpty)
        #expect(!state.isSearchPresented)
        #expect(state.focusRouter.consume(matching: { if case .log = $0 { true } else { false } }) == .log("abc"))
    }

    @Test func emotionRequestPushesEmotionOnHome() {
        let state = AppState()
        state.selectedTab = .settings
        state.focusRouter.request(.emotion)
        #expect(state.selectedTab == .home)
        #expect(state.homePath == [.emotion])
    }

    @Test func taskRequestPushesCalendarOnStats() {
        let state = AppState()
        state.focusRouter.request(.task("2026-10-23"))
        #expect(state.selectedTab == .stats)
        #expect(state.statsPath == [.calendar])
    }

    @Test func pushFromTablessTabFallsBackToHome() {
        let state = AppState()
        state.selectedTab = .memory
        state.push(.emotion)
        #expect(state.selectedTab == .home)
        #expect(state.homePath == [.emotion])
    }
}
