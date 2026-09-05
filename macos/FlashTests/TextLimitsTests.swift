// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import Flash

@Suite("契约文本上限（UTF-16 口径）")
struct TextLimitsTests {
    @Test func contentLimitBoundary() {
        #expect(TextLimits.fits(String(repeating: "a", count: 100_000)))
        #expect(!TextLimits.fits(String(repeating: "a", count: 100_001)))
    }

    @Test func titleLimitBoundary() {
        #expect(TextLimits.fits(String(repeating: "a", count: 200), limit: TextLimits.maxTaskTitleUTF16))
        #expect(!TextLimits.fits(String(repeating: "a", count: 201), limit: TextLimits.maxTaskTitleUTF16))
    }

    @Test func emojiCountAsTwoUTF16Units() {
        // 200 个 emoji = 400 UTF-16 单元：Character.count 口径会误判为未超标题上限
        let emojis = String(repeating: "😀", count: 200)
        #expect(emojis.count == 200)
        #expect(emojis.utf16.count == 400)
        #expect(!TextLimits.fits(emojis, limit: TextLimits.maxTaskTitleUTF16))
        // 100 个 emoji 恰好 200 单元，未超标题上限
        #expect(TextLimits.fits(String(repeating: "😀", count: 100), limit: TextLimits.maxTaskTitleUTF16))
        // 50_000 个 emoji 恰好 100,000 单元，未超正文上限；多一个即超限
        #expect(TextLimits.fits(String(repeating: "😀", count: 50_000)))
        #expect(!TextLimits.fits(String(repeating: "😀", count: 50_001)))
    }
}
