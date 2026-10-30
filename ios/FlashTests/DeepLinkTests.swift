// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
import FlashCore
@testable import Flash

/// flash:// 深链（小组件 / 通知 / 控制中心 / 快捷指令共用入口）
@Suite("iOS 深链")
struct DeepLinkTests {
    @Test func captureOpensQuickCaptureWithCategory() throws {
        let state = AppState()
        state.isSearchPresented = true
        #expect(state.handle(url: try #require(URL(string: "flash://capture?category=log"))))
        #expect(state.quickCapture?.category == .log)
        #expect(!state.isSearchPresented)
    }

    @Test func captureWithoutCategoryKeepsDraftDefault() throws {
        let state = AppState()
        state.handle(url: try #require(URL(string: "flash://capture")))
        #expect(state.quickCapture != nil)
        #expect(state.quickCapture?.category == nil)
    }

    @Test func ideasOpensExploreFilteredToIdeas() throws {
        let state = AppState()
        state.explorePath = [.logFlow]
        state.handle(url: try #require(URL(string: "flash://ideas")))
        #expect(state.selectedTab == .explore)
        #expect(state.explorePath.isEmpty)
        #expect(state.exploreFilterRequest == .idea)
    }

    @Test func todayReturnsToHome() throws {
        let state = AppState()
        state.selectedTab = .settings
        state.homePath = [.emotion]
        state.handle(url: try #require(URL(string: "flash://today")))
        #expect(state.selectedTab == .home)
        #expect(state.homePath.isEmpty)
    }

    @Test func unknownLinksAreIgnored() throws {
        let state = AppState()
        #expect(!state.handle(url: try #require(URL(string: "flash://nope"))))
        #expect(!state.handle(url: try #require(URL(string: "https://example.com/capture"))))
        #expect(state.quickCapture == nil)
    }

    @Test func destinationLinksDismissObscuringPresentations() throws {
        for link in ["flash://today", "flash://ideas"] {
            let state = AppState()
            state.presentQuickCapture(category: .log)
            state.isSearchPresented = true
            #expect(state.handle(url: try #require(URL(string: link))))
            #expect(!state.isSearchPresented)
            #expect(state.quickCapture == nil)
            #expect(state.selectedTab == (link == "flash://today" ? .home : .explore))
        }
    }

    @Test func unknownLinkPreservesActivePresentation() throws {
        let state = AppState()
        state.presentQuickCapture(category: .log)
        let request = state.quickCapture
        #expect(!state.handle(url: try #require(URL(string: "flash://unsupported"))))
        #expect(state.quickCapture == request)
    }
}
