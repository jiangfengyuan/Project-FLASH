// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import Flash

@Suite("ReviewInsights 窗口对比")
struct ReviewInsightsTests {
    // 夹具：固定 today = 2026-08-13（周四）
    private let today = DateFormatting.parseDay("2026-08-13")!

    private func emotion(_ day: String, _ level: EmotionLevel) -> EmotionRecord {
        EmotionRecord(id: UUID().uuidString, level: level, subEmotion: nil,
                      status: nil, note: nil, recordDate: day,
                      createdAt: "\(day)T08:00:00.000Z")
    }

    private func log(_ day: String) -> LogItem {
        LogItem(id: UUID().uuidString, content: "x", colorTag: .daily,
                category: .log, importance: 0,
                createdAt: "\(day)T08:00:00.000Z", recordDate: day)
    }

    @Test func insufficientDataAsksToKeepRecording() {
        // 两窗口合计 4 条 < 5：不给趋势结论
        let logs = [log("2026-08-13"), log("2026-08-12"), log("2026-08-11"), log("2026-08-06")]
        let result = ReviewInsights.compare(logs: logs, emotions: [], window: .week, today: today)
        #expect(!result.hasEnoughData)
        #expect(result.conclusion == "继续记录，回顾会慢慢清晰")
        #expect(result.currentCount == 3)
        #expect(result.previousCount == 1)
    }

    @Test func moreActiveThanPreviousWindow() {
        let current = (0..<6).map { _ in log("2026-08-13") }
        let previous = [log("2026-08-07")]
        let result = ReviewInsights.compare(logs: current + previous, emotions: [],
                                            window: .week, today: today)
        #expect(result.hasEnoughData)
        #expect(result.activityTrend == .more)
        #expect(result.conclusion == "这周你记录得比上周更频繁")
    }

    @Test func lessActiveAndMoodLower() {
        let result = ReviewInsights.compare(
            logs: [log("2026-08-12")],
            emotions: [emotion("2026-08-12", .unhappy),
                       emotion("2026-08-07", .happy), emotion("2026-08-07", .happy),
                       emotion("2026-08-08", .happy), emotion("2026-08-09", .happy)],
            window: .week, today: today)
        // 当前 2 条 vs 前窗 4 条，合计 6 ≥ 5
        #expect(result.hasEnoughData)
        #expect(result.activityTrend == .less)
        #expect(result.moodTrend == .lower)
        #expect(result.conclusion == "这周的记录不如上周活跃，情绪整体更低落一些")
    }

    @Test func sameActivityWithBetterMood() {
        let result = ReviewInsights.compare(
            logs: [log("2026-08-13"), log("2026-08-13"), log("2026-08-07"),
                   log("2026-08-07")],
            emotions: [emotion("2026-08-13", .veryHappy), emotion("2026-08-08", .neutral)],
            window: .week, today: today)
        // 当前 3 条（2 日志 + 1 情绪）vs 前窗 3 条（2 日志 + 1 情绪）→ 持平；情绪 3.0 vs 0.0 → 更好
        #expect(result.hasEnoughData)
        #expect(result.activityTrend == .same)
        #expect(result.moodTrend == .better)
        #expect(result.conclusion == "这周的记录与上周持平，情绪整体更好一些")
    }

    @Test func rollingWindowLabelsAndRanges() {
        // 近30天：当前窗 2026-07-15 ~ 08-13，前窗 2026-06-14 ~ 07-14
        let current = (0..<5).map { _ in log("2026-08-01") }
        let previous = [log("2026-07-01"), log("2026-06-20")]
        let result = ReviewInsights.compare(logs: current + previous, emotions: [],
                                            window: .days30, today: today)
        #expect(result.currentCount == 5)
        #expect(result.previousCount == 2)
        #expect(result.activityTrend == .more)
        #expect(result.conclusion == "近 30 天你记录得比之前 30 天更频繁")
    }

    @Test func weekWindowStartsMondayAndPreviousIsAlignedWeekdays() {
        // 周四视角本周窗口为 08-10 ~ 08-13（4 天），前窗为 08-06 ~ 08-09（同样 4 天）
        // 08-04（上周二）应落在前窗之外
        let logs = [log("2026-08-10"), log("2026-08-13"),
                    log("2026-08-06"), log("2026-08-09"), log("2026-08-04")]
        let result = ReviewInsights.compare(logs: logs, emotions: [], window: .week, today: today)
        #expect(result.currentCount == 2)
        #expect(result.previousCount == 2)
        // 合计 4 < 5，数据不足
        #expect(!result.hasEnoughData)
    }

    @Test func monthWindowLabels() {
        // 2026-08-13 的本月窗口为 08-01 ~ 08-13（13 天），前窗 07-19 ~ 07-31
        let current = (0..<4).map { _ in log("2026-08-05") }
        let previous = [log("2026-07-25"), log("2026-07-20")]
        let outside = [log("2026-07-18")]  // 前窗之前，不计入
        let result = ReviewInsights.compare(logs: current + previous + outside, emotions: [],
                                            window: .month, today: today)
        #expect(result.currentCount == 4)
        #expect(result.previousCount == 2)
        #expect(result.conclusion == "这个月你记录得比上个月更频繁")
    }

    @Test func moodUnknownWhenEitherWindowLacksEmotions() {
        // 当前 3 条（2 日志 + 1 情绪）vs 前窗 3 日志 → 持平；前窗无情绪 → moodTrend 未知
        let logs = (0..<2).map { _ in log("2026-08-13") } + (0..<3).map { _ in log("2026-08-07") }
        let result = ReviewInsights.compare(logs: logs, emotions: [emotion("2026-08-13", .happy)],
                                            window: .week, today: today)
        #expect(result.hasEnoughData)
        #expect(result.moodTrend == .unknown)
        #expect(result.conclusion == "这周的记录与上周持平")
        #expect(result.currentEmotionAverage == 2.0)
        #expect(result.previousEmotionAverage == nil)
    }

    @Test func moodAveragesRoundHalfUp() {
        // 前窗均值 (-1 + 0 + 0) / 3 = -0.333… → half-up 两位小数 = -0.33
        let emotions = [emotion("2026-08-07", .slightlyUnhappy),
                        emotion("2026-08-07", .neutral),
                        emotion("2026-08-08", .neutral)]
        let logs = (0..<5).map { _ in log("2026-08-13") }
        let result = ReviewInsights.compare(logs: logs, emotions: emotions,
                                            window: .week, today: today)
        #expect(result.previousEmotionAverage == -0.33)
    }
}
