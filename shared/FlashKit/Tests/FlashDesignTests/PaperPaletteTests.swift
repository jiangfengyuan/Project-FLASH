// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashDesign

/// 「纸上书写」色板：与跨端令牌文件逐项一致、满足 WCAG AA、不含纯黑。
/// 纯 hex 计算，不依赖外观解析，macOS 宿主即可校验 iOS 色值。
@Suite("纸上书写色板")
struct PaperPaletteTests {
    nonisolated(unsafe) private static let tokens: [String: Any] = {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try! Data(contentsOf: root.appendingPathComponent("docs/design/paper-tokens.json"))
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }()

    private static let named: [String: PaperPalette.Pair] = [
        "pageBackground": PaperPalette.pageBackground, "cardSurface": PaperPalette.cardSurface,
        "weakSurface": PaperPalette.weakSurface, "parchment": PaperPalette.parchment,
        "weakBorder": PaperPalette.weakBorder, "textPrimary": PaperPalette.textPrimary,
        "textSecondary": PaperPalette.textSecondary, "textTertiary": PaperPalette.textTertiary,
        "brandPrimary": PaperPalette.brandPrimary, "onBrandPrimary": PaperPalette.onBrandPrimary,
        "brandFill": PaperPalette.brandFill,
        "chipSelectedBackground": PaperPalette.chipSelectedBackground,
        "chipSelectedForeground": PaperPalette.chipSelectedForeground,
        "logPurple": PaperPalette.logPurple, "ideaYellow": PaperPalette.ideaYellow,
        "ideaYellowText": PaperPalette.ideaYellowText, "calendarGreen": PaperPalette.calendarGreen,
        "accessibleGreen": PaperPalette.accessibleGreen, "emotionPink": PaperPalette.emotionPink,
        "emotionPinkText": PaperPalette.emotionPinkText, "destructive": PaperPalette.destructive,
        "shadowTint": PaperPalette.shadowTint, "scrim": PaperPalette.scrim,
    ]

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

    private func expectMatches(_ pair: PaperPalette.Pair?, _ json: Any?, _ name: String) {
        let values = json as? [String: String]
        #expect(pair?.light == values?["light"], "\(name) light")
        #expect(pair?.dark == values?["dark"], "\(name) dark")
    }

    @Test func colorsMatchSharedTokens() {
        let colors = Self.tokens["colors"] as! [String: Any]
        #expect(Set(colors.keys) == Set(Self.named.keys))
        for (name, json) in colors { expectMatches(Self.named[name], json, name) }
    }

    @Test func dataColorsMatchSharedTokens() {
        let tags = Self.tokens["tags"] as! [String: [String: Any]]
        #expect(Set(tags.keys) == Set(PaperPalette.tags.keys))
        for (name, tone) in tags {
            expectMatches(PaperPalette.tags[name]?.fill, tone["fill"], "\(name) fill")
            expectMatches(PaperPalette.tags[name]?.text, tone["text"], "\(name) text")
        }
        let moods = Self.tokens["moods"] as! [String: Any]
        #expect(moods.count == PaperPalette.moods.count)
        for (level, json) in moods { expectMatches(PaperPalette.moods[Int(level)!], json, "mood \(level)") }
        let subs = Self.tokens["subEmotions"] as! [String: Any]
        #expect(subs.count == PaperPalette.subEmotions.count)
        for (name, json) in subs { expectMatches(PaperPalette.subEmotions[name], json, name) }
    }

    @Test func allContrastRulesPass() {
        let rules = Self.tokens["contrast"] as! [[String: Any]]
        #expect(!rules.isEmpty)
        for rule in rules {
            let fg = Self.named[rule["fg"] as! String]!
            let minimum = (rule["min"] as! NSNumber).doubleValue
            for name in rule["bg"] as! [String] {
                let bg = Self.named[name]!
                #expect(contrast(fg.light, bg.light) >= minimum, "\(rule["fg"]!) on \(name) light")
                #expect(contrast(fg.dark, bg.dark) >= minimum, "\(rule["fg"]!) on \(name) dark")
            }
        }
    }

    @Test func tagTextIsReadableOnPaper() {
        for (name, tone) in PaperPalette.tags {
            for bg in [PaperPalette.pageBackground, PaperPalette.cardSurface] {
                #expect(contrast(tone.text.light, bg.light) >= 4.5, "\(name) light")
                #expect(contrast(tone.text.dark, bg.dark) >= 4.5, "\(name) dark")
            }
        }
    }

    @Test func noPureBlackAnywhere() {
        for (name, pair) in Self.named {
            #expect(pair.light.uppercased() != "#000000", "\(name)")
            #expect(pair.dark.uppercased() != "#000000", "\(name)")
        }
    }

    /// 三端抖动算法必须一致：同一种子画出同样的线
    @Test func jitterMatchesCrossPlatformVectors() {
        let vectors = Self.tokens["jitterVectors"] as! [[String: Any]]
        #expect(!vectors.isEmpty)
        for vector in vectors {
            var jitter = SeededJitter(seed: vector["seed"] as! String)
            for expected in vector["values"] as! [NSNumber] {
                #expect(abs(Double(jitter.next()) - expected.doubleValue) < 1e-9)
            }
        }
    }
}
