// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashDesign

/// iOS 暖调手作主题的对比度门槛（WCAG 2.x）：正文/小号文字 ≥ 4.5:1。
/// 纯 hex 计算，不依赖外观解析，macOS 宿主即可校验 iOS 色值。
@Suite("暖调色板对比度")
struct WarmPaletteTests {
    private func luminance(_ hex: String) -> Double {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(digits, radix: 16)!
        let channels = [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF].map { channel -> Double in
            let c = Double(channel) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// 文字色 × 承载它的表面
    private static let textPairs: [(name: String, fg: WarmPalette.Pair, bg: [WarmPalette.Pair])] = [
        ("主文字", WarmPalette.textPrimary,
         [WarmPalette.pageBackground, WarmPalette.cardSurface, WarmPalette.weakSurface]),
        ("次文字", WarmPalette.textSecondary,
         [WarmPalette.pageBackground, WarmPalette.cardSurface, WarmPalette.weakSurface]),
        ("陶土强调", WarmPalette.brandPrimary,
         [WarmPalette.pageBackground, WarmPalette.cardSurface, WarmPalette.weakSurface]),
        ("灵感文字", WarmPalette.ideaYellowText, [WarmPalette.pageBackground, WarmPalette.cardSurface]),
        ("可访问绿", WarmPalette.accessibleGreen, [WarmPalette.pageBackground, WarmPalette.cardSurface]),
        ("陶土底上文字", WarmPalette.onBrandPrimary, [WarmPalette.brandPrimary]),
        ("选中 Chip", WarmPalette.chipSelectedForeground, [WarmPalette.chipSelectedBackground]),
    ]

    @Test(arguments: textPairs.map(\.name))
    func textMeetsAA(_ name: String) {
        let pair = Self.textPairs.first { $0.name == name }!
        for bg in pair.bg {
            let light = contrast(pair.fg.light, bg.light)
            let dark = contrast(pair.fg.dark, bg.dark)
            #expect(light >= 4.5, "\(name) 浅色 \(pair.fg.light) on \(bg.light) = \(light)")
            #expect(dark >= 4.5, "\(name) 深色 \(pair.fg.dark) on \(bg.dark) = \(dark)")
        }
    }

    /// 模块色只作图标/点缀：非文字图形 ≥ 3:1（WCAG 1.4.11）
    @Test func moduleAccentsMeetGraphicContrast() {
        for accent in [WarmPalette.logPurple, WarmPalette.emotionPink, WarmPalette.calendarGreen] {
            #expect(contrast(accent.light, WarmPalette.cardSurface.light) >= 3)
            #expect(contrast(accent.dark, WarmPalette.cardSurface.dark) >= 3)
        }
    }
}
