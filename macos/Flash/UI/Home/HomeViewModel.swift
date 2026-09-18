// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Home 此刻页的数据装配层：注入 logs/emotions/today，集中计算今日一览计数、
/// 最近闪念与情绪状态。仅在注入数据变化时重算，
/// 避免视图每次 body 求值（如草稿按键）都全量分组统计。
/// 不依赖 SwiftUI，可直接构造注入数据单测。
@Observable
final class HomeViewModel {

    /// 「情绪状态」的装配数据（今日一览卡使用 emoji + title）
    struct EmotionSnapshot {
        let emoji: String
        let title: String
        let summary: String
        /// 周一到周日每天的情绪均值（0–6 标尺），无数据为 nil
        let points: [Double?]
    }

    // MARK: - 注入数据

    private(set) var logs: [LogItem]
    private(set) var emotions: [EmotionRecord]
    /// 日期窗口（近 7 天）的基准时刻
    private(set) var today: Date
    /// today 对应的本地 yyyy-MM-dd（与 recordDate 比较用，字典序即时间序）
    private(set) var todayString: String

    // MARK: - 派生数据（仅 update 时重算，视图直接读取）

    /// 今日一览卡：今日记录数（日志 + 灵感合计）
    private(set) var todayRecordCount = 0
    /// 今日一览卡：今日灵感数
    private(set) var todayIdeaCount = 0
    /// 「最近闪念」：全部日志/灵感按创建时间倒序的前 6 条（注入的 logs 本身即倒序）
    private(set) var recentLogs: [LogItem] = []
    private(set) var emotionSnapshot: EmotionSnapshot

    /// 无情绪记录时的占位快照
    private static let placeholderSnapshot = EmotionSnapshot(
        emoji: "🙂", title: "还没有记录", summary: "记录第一条情绪吧",
        points: Array(repeating: nil, count: 7))

    init(logs: [LogItem] = [], emotions: [EmotionRecord] = [], today: Date = Date()) {
        self.logs = logs
        self.emotions = emotions
        self.today = today
        self.todayString = DateFormatting.dayString(today)
        self.emotionSnapshot = Self.placeholderSnapshot
        recompute()
    }

    /// 注入最新数据；与现状相同则直接返回（按键等无关 body 求值不会触发重算）
    func update(logs: [LogItem], emotions: [EmotionRecord], today: Date = Date()) {
        let todayString = DateFormatting.dayString(today)
        guard logs != self.logs || emotions != self.emotions || todayString != self.todayString else { return }
        self.logs = logs
        self.emotions = emotions
        self.today = today
        self.todayString = todayString
        recompute()
    }

    private func recompute() {
        todayRecordCount = todayLogs.count + todayIdeas.count
        todayIdeaCount = todayIdeas.count
        recentLogs = Array(logs.prefix(6))
        emotionSnapshot = makeEmotionSnapshot()
    }

    // MARK: - 今日计数

    private var todayLogs: [LogItem] { logs.filter { $0.recordDate == todayString && $0.category == .log } }
    private var todayIdeas: [LogItem] { logs.filter { $0.recordDate == todayString && $0.category == .idea } }

    // MARK: - 情绪状态

    private func makeEmotionSnapshot() -> EmotionSnapshot {
        guard let latest = emotions.first else { return Self.placeholderSnapshot }
        let summary: String
        if let average = last7EmotionAverage() {
            if average >= 3.5 {
                summary = "本周整体偏积极"
            } else if average <= 2.5 {
                summary = "本周情绪偏低落"
            } else {
                summary = "本周情绪平稳"
            }
        } else {
            summary = "本周暂无记录"
        }
        return EmotionSnapshot(emoji: latest.level.emoji,
                               title: latest.level.displayName,
                               summary: summary,
                               points: weeklyEmotionPoints())
    }

    /// 本周一到周日每天的情绪均值（0–6 标尺，由 level.rawValue -3...3 平移而来；无数据为 nil）。
    /// 经 EmotionStats.dailyAverages(onDays:) 按周一到周日对齐。
    private func weeklyEmotionPoints() -> [Double?] {
        EmotionStats.dailyAverages(emotions, onDays: DateWindows.currentWeek(today: today))
            .map { $0.map { $0 + 3 } }
    }

    /// 近 7 天情绪均值（0–6 标尺）；无记录返回 nil
    private func last7EmotionAverage() -> Double? {
        let days = DateWindows.lastNDays(7, today: today)
        guard let start = days.first, let end = days.last else { return nil }
        let values = emotions.filter { $0.recordDate >= start && $0.recordDate <= end }
            .map { $0.level.rawValue + 3 }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}
