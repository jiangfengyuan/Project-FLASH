// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

/// 多语言不能碰存储值，也不能让没有目录的 macOS 变成半翻译界面。
@Suite("本地化与存储值隔离")
struct LocalizationSafetyTests {
    private static let sample = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func withoutCatalogLReturnsChineseSource() {
        #expect(L("现在想记录什么？") == "现在想记录什么？")
    }

    @Test func storedDatesAreAsciiWhateverTheDeviceLanguage() {
        let stored = [
            DateFormatting.dayString(Self.sample),
            DateFormatting.monthString(Self.sample),
            DateFormatting.today(),
            DateFormatting.isoNow(),
        ]
        for value in stored {
            #expect(value.utf8.allSatisfy { $0 < 128 }, "\(value)")
            #expect(!value.contains("٠"))
        }
        #expect(DateFormatting.dayString(Self.sample).wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil)
        #expect(DateFormatting.monthString(Self.sample).wholeMatch(of: /\d{4}-\d{2}/) != nil)
    }

    @Test func dayStringsRoundTrip() throws {
        let day = DateFormatting.dayString(Self.sample)
        #expect(DateFormatting.dayString(try #require(DateFormatting.parseDay(day))) == day)
    }

    #if os(macOS)
    @Test func macMonthTitleStaysChinese() {
        #expect(DateFormatting.monthTitle(Self.sample).hasSuffix("月"))
        #expect(DateFormatting.monthTitle(Self.sample).contains("年"))
    }
    #endif
}
