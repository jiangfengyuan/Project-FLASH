// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Memory 周报聚合（PRD §22 V1.1 规则版，无 AI）：把「周一到周日」自然周内的
/// 日志/灵感/任务/情绪聚合成一份可回看的周报。纯函数、无 UI 依赖；
/// recordDate 为 yyyy-MM-dd，字典序即时间序（与 EmotionStats 同口径）。
enum WeeklyMemory {

    struct Report: Equatable {
        /// 情绪概览：周均值 + 文案（PRD §22.2「This week felt...」）
        struct MoodSummary: Equatable {
            /// 两位小数均值（舍入口径对齐 EmotionStats / ReviewInsights）
            let average: Double
            let emoji: String
            let text: String
        }

        /// 周界显示串（yyyy-MM-dd）
        let weekStart: String
        let weekEnd: String
        /// 四类计数：日志 / 灵感 / 任务（按 calendarDate 落周）/ 情绪
        let moments: Int
        let ideas: Int
        let tasks: Int
        let emotions: Int
        /// 本周无情绪记录时为 nil（UI 隐藏情绪概览区块）
        let mood: MoodSummary?
        /// 本周亮点标题（收藏优先，其次高重要度，最多 highlightLimit 条）
        let highlights: [String]
        /// 空周标记：四类计数全 0
        let hasData: Bool
    }

    /// 亮点条数上限（PRD §22.2 示意 4 条）
    static let highlightLimit = 4
    /// 情绪均值文案边界（-3~+3 量表）：|均值| 不足 1 视为整体平稳，
    /// 与 ReviewInsights.moodChangeThreshold(0.5) 相比更保守——周报是整周基调，
    /// 单日波动不应轻易定性为积极/低落
    static let positiveThreshold = 1.0
    static let negativeThreshold = -1.0

    static func report(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem],
                       baseDate: Date = Date()) -> Report {
        let days = DateWindows.currentWeek(today: baseDate)
        let weekStart = days.first!
        let weekEnd = days.last!

        func inWeek(_ day: String) -> Bool { day >= weekStart && day <= weekEnd }

        let weekLogs = logs.filter { inWeek($0.recordDate) }
        let weekEmotions = emotions.filter { inWeek($0.recordDate) }
        let weekTasks = tasks.filter { task in
            guard let calendarDate = task.calendarDate else { return false }
            return inWeek(calendarDate)
        }

        let moments = weekLogs.filter { $0.category == .log }.count
        let ideas = weekLogs.filter { $0.category == .idea }.count

        let mood = moodSummary(of: weekEmotions)
        let highlights = weekLogs
            .sorted { lhs, rhs in
                // 收藏优先，其次重要度降序、创建时间降序（ISO-8601 字典序即时间序）
                let lf = lhs.isFavorite ?? false
                let rf = rhs.isFavorite ?? false
                if lf != rf { return lf }
                if lhs.importance != rhs.importance { return lhs.importance > rhs.importance }
                return lhs.createdAt > rhs.createdAt
            }
            .prefix(highlightLimit)
            .map { highlightTitle(of: $0) }

        return Report(weekStart: weekStart, weekEnd: weekEnd,
                      moments: moments, ideas: ideas,
                      tasks: weekTasks.count, emotions: weekEmotions.count,
                      mood: mood, highlights: highlights,
                      hasData: moments + ideas + weekTasks.count + weekEmotions.count > 0)
    }

    /// 情绪文案：≥ +1 偏积极 / ≤ -1 偏低落 / 否则平稳（阈值见 positiveThreshold 注释）
    private static func moodSummary(of emotions: [EmotionRecord]) -> Report.MoodSummary? {
        guard !emotions.isEmpty else { return nil }
        let mean = Double(emotions.reduce(0) { $0 + $1.level.rawValue }) / Double(emotions.count)
        // 舍入口径对齐 EmotionStats.dailyAverages：Kotlin Math.round 风格 half-up
        let average = (mean * 100 + 0.5).rounded(.down) / 100
        let summary: (emoji: String, text: String)
        if average >= positiveThreshold {
            summary = ("😊", "Mostly Positive")
        } else if average <= negativeThreshold {
            summary = ("😔", "Mostly Low")
        } else {
            summary = ("🙂", "Mostly Steady")
        }
        return Report.MoodSummary(average: average, emoji: summary.emoji, text: summary.text)
    }

    /// 亮点标题：取内容首行，去掉首尾空白；空内容兜底占位
    private static func highlightTitle(of log: LogItem) -> String {
        let firstLine = log.content
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "（无标题）" : trimmed
    }
}
