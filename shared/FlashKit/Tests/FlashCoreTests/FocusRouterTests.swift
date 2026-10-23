// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import FlashCore

@Suite("FocusRouter 跨模块定位")
struct FocusRouterTests {
    @Test func requestRoutesHostBeforeDelivering() {
        let router = FocusRouter()
        var routed: [FocusDestination] = []
        router.onRequest = { routed.append($0) }
        router.request(.log("a"))
        #expect(routed == [.log("a")])
        #expect(router.requestToken == 1)
        #expect(router.consume() == .log("a"))
    }

    @Test func eachRequestIsDeliveredOnce() {
        let router = FocusRouter()
        router.request(.task("2026-10-23"))
        #expect(router.consume() == .task("2026-10-23"))
        #expect(router.consume() == nil)
        router.request(.emotion)
        #expect(router.consume() == .emotion)
        #expect(router.consume() == nil)
    }

    @Test func nothingPendingReturnsNil() {
        #expect(FocusRouter().consume() == nil)
    }
}
