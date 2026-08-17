// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
@testable import Flash

@Suite("数据模型三端对齐")
struct ModelsTests {
    @Test func colorTagStorageKeys() {
        #expect(ColorTag.urgent.rawValue == "urgent")
        #expect(ColorTag.inspiration.rawValue == "inspiration")
        #expect(ColorTag.daily.rawValue == "daily")
        #expect(ColorTag.memo.rawValue == "memo")
        #expect(ColorTag.emotion.rawValue == "emotion")
        #expect(ColorTag.idea.rawValue == "idea")
        #expect(ColorTag.allCases.count == 6)
    }

    @Test func colorTagDisplayAndHex() {
        #expect(ColorTag.urgent.displayName == "紧急")
        #expect(ColorTag.urgent.colorHex == "#FF6B6B")
        #expect(ColorTag.inspiration.colorHex == "#FFD93D")
        #expect(ColorTag.daily.colorHex == "#4D96FF")
        #expect(ColorTag.memo.colorHex == "#6BCB77")
        #expect(ColorTag.emotion.colorHex == "#9B59B6")
        #expect(ColorTag.idea.colorHex == "#FF9F43")
    }

    @Test func emotionLevelValues() {
        #expect(EmotionLevel.veryUnhappy.rawValue == -3)
        #expect(EmotionLevel.neutral.rawValue == 0)
        #expect(EmotionLevel.veryHappy.rawValue == 3)
        #expect(EmotionLevel.allCases.count == 7)
        #expect(EmotionLevel(rawValue: -3)?.displayName == "非常不开心")
        #expect(EmotionLevel.veryUnhappy.isNegative)
        #expect(!EmotionLevel.neutral.isNegative)
        #expect(EmotionLevel.veryHappy.emoji == "😍")
        #expect(EmotionLevel.veryUnhappy.emoji == "😡")
    }

    @Test func subEmotionKeys() {
        #expect(SubEmotion.sad.rawValue == "sad")
        #expect(SubEmotion.sad.displayName == "伤心")
        #expect(SubEmotion(rawValue: "nope") == nil)
    }

    @Test func importanceFromContentRules() {
        #expect(importanceFromContent("普通") == 0)
        #expect(importanceFromContent("重要!!") == 2)
        #expect(importanceFromContent("更重要!!!") == 3)
        #expect(importanceFromContent("紧急!!!!") == 4)
    }
}
