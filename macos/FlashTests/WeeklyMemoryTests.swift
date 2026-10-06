// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import Flash

@Suite("WeeklyMemory 周报聚合")
struct WeeklyMemoryTests {
    // 夹具：固定基准日 = 2026-08-13（周四），所在自然周为 2026-08-10（周一）~ 2026-08-16（周日）
    private let baseDate = DateFormatting.parseDay("2026-08-13")!

    private func log(_ day: String, content: String = "x", category: Flash.Category = .log,
                     importance: Int = 0, isFavorite: Bool? = nil,
                     createdAt: String? = nil) -> LogItem {
        LogItem(id: UUID().uuidString, content: content, colorTag: .daily,
                category: category, importance: importance, isFavorite: isFavorite,
                createdAt: createdAt ?? "\(day)T08:00:00.000Z", recordDate: day)
    }

    private func emotion(_ day: String, _ level: EmotionLevel) -> EmotionRecord {
        EmotionRecord(id: UUID().uuidString, level: level, subEmotion: nil,
                      status: nil, note: nil, recordDate: day,
                      createdAt: "\(day)T08:00:00.000Z")
    }

    private func allDayTask(_ day: String?) -> TaskItem {
        TaskItem(id: UUID().uuidString, title: "t", notes: nil, colorTag: .daily,
                 importance: 0, dueKind: .allDay, dueDate: day, dueAt: nil,
                 timeZone: nil, reminderAt: nil, completedAt: nil,
                 createdAt: "2026-08-13T08:00:00.000Z", updatedAt: "2026-08-13T08:00:00.000Z")
    }

    @Test func emptyWeekHasNoData() {
        let report = WeeklyMemory.report(logs: [], emotions: [], tasks: [], baseDate: baseDate)
        #expect(report.weekStart == "2026-08-10")
        #expect(report.weekEnd == "2026-08-16")
        #expect(report.moments == 0 && report.ideas == 0)
        #expect(report.tasks == 0 && report.emotions == 0)
        #expect(report.highlights.isEmpty)
        #expect(report.mood == nil)
        #expect(!report.hasData)
    }

    @Test func countsEachCategoryInWeek() {
        let report = WeeklyMemory.report(
            logs: [log("2026-08-10"), log("2026-08-11"),
                   log("2026-08-12", category: .idea)],
            emotions: [emotion("2026-08-13", .happy), emotion("2026-08-14", .neutral)],
            tasks: [allDayTask("2026-08-15")],
            baseDate: baseDate)
        #expect(report.moments == 2)
        #expect(report.ideas == 1)
        #expect(report.tasks == 1)
        #expect(report.emotions == 2)
        #expect(report.hasData)
    }

    @Test func weekBoundariesIncludeMondayAndSundayOnly() {
        // 08-10（周一）与 08-16（周日）计入本周；08-09、08-17 不计
        let report = WeeklyMemory.report(
            logs: [log("2026-08-10"), log("2026-08-16"),
                   log("2026-08-09"), log("2026-08-17")],
            emotions: [emotion("2026-08-09", .happy)],
            tasks: [allDayTask("2026-08-16"), allDayTask("2026-08-17")],
            baseDate: baseDate)
        #expect(report.moments == 2)
        #expect(report.tasks == 1)
        #expect(report.emotions == 0)
    }

    @Test func tasksCountByCalendarDate() {
        // 全日任务按 dueDate 落周；dateTime 任务按 timeZone 换算后的日历日落周
        let zoned = TaskItem(id: UUID().uuidString, title: "z", notes: nil, colorTag: .daily,
                             importance: 0, dueKind: .dateTime, dueDate: nil,
                             dueAt: "2026-08-12T02:00:00Z", timeZone: "Asia/Shanghai",
                             reminderAt: nil, completedAt: nil,
                             createdAt: "2026-08-12T00:00:00.000Z",
                             updatedAt: "2026-08-12T00:00:00.000Z")
        let report = WeeklyMemory.report(
            logs: [], emotions: [],
            tasks: [allDayTask("2026-08-11"), allDayTask(nil), zoned],
            baseDate: baseDate)
        // allDay(08-11) + dateTime（北京时间 08-12）计入；无日期任务不计
        #expect(report.tasks == 2)
    }

    @Test func highlightsFavoritesFirstThenImportance() {
        // 4 条非收藏（importance 4/3/2/1）+ 1 条收藏（importance 0）：
        // 收藏排最前，其后按重要度降序，取前 4
        let logs = [
            log("2026-08-12", content: "普通4", importance: 4),
            log("2026-08-12", content: "普通3", importance: 3),
            log("2026-08-12", content: "普通2", importance: 2),
            log("2026-08-12", content: "普通1", importance: 1),
            log("2026-08-12", content: "收藏", importance: 0, isFavorite: true)
        ]
        let report = WeeklyMemory.report(logs: logs, emotions: [], tasks: [], baseDate: baseDate)
        #expect(report.highlights == ["收藏", "普通4", "普通3", "普通2"])
    }

    @Test func highlightsTieBreakByCreatedAtDesc() {
        let logs = [
            log("2026-08-12", content: "早", importance: 2, createdAt: "2026-08-12T08:00:00.000Z"),
            log("2026-08-12", content: "晚", importance: 2, createdAt: "2026-08-12T20:00:00.000Z")
        ]
        let report = WeeklyMemory.report(logs: logs, emotions: [], tasks: [], baseDate: baseDate)
        #expect(report.highlights == ["晚", "早"])
    }

    @Test func highlightsOnlyFromThisWeekAndUseFirstLine() {
        let logs = [
            log("2026-08-09", content: "上周的事", isFavorite: true),
            log("2026-08-12", content: "  多行\n第二行  ", isFavorite: true)
        ]
        let report = WeeklyMemory.report(logs: logs, emotions: [], tasks: [], baseDate: baseDate)
        #expect(report.highlights == ["多行"])
    }

    @Test func moodTextBoundaries() {
        func mood(_ levels: [EmotionLevel]) -> WeeklyMemory.Report.MoodSummary? {
            WeeklyMemory.report(logs: [], emotions: levels.map { emotion("2026-08-13", $0) },
                                tasks: [], baseDate: baseDate).mood
        }
        // 均值恰好 +1 → 偏积极（阈值含边界）
        let positive = mood([.slightlyHappy, .slightlyHappy, .slightlyHappy])
        #expect(positive?.text == "Mostly Positive")
        #expect(positive?.average == 1.0)
        // 均值恰好 -1 → 偏低落
        #expect(mood([.slightlyUnhappy, .slightlyUnhappy])?.text == "Mostly Low")
        // 均值 0.5（|均值| < 1）→ 平稳
        let steady = mood([.slightlyHappy, .neutral])
        #expect(steady?.text == "Mostly Steady")
        #expect(steady?.average == 0.5)
        // 负均值舍入对齐 half-up：(-1 + 0 + 0) / 3 → -0.33
        #expect(mood([.slightlyUnhappy, .neutral, .neutral])?.average == -0.33)
    }

    @Test func baseDateInPreviousWeekAggregatesThatWeek() {
        // 跨周导航基准：基准日 08-05（上周三）→ 周窗 08-03 ~ 08-09
        let previousWeek = DateFormatting.parseDay("2026-08-05")!
        let report = WeeklyMemory.report(
            logs: [log("2026-08-03"), log("2026-08-09"), log("2026-08-10")],
            emotions: [], tasks: [], baseDate: previousWeek)
        #expect(report.weekStart == "2026-08-03")
        #expect(report.weekEnd == "2026-08-09")
        #expect(report.moments == 2)
    }
}
