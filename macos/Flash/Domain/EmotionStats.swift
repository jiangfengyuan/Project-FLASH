// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 情绪统计算法，与 Android EmotionStats.kt / Web emotionStats.ts 一一对应。
enum EmotionStats {

    private static func window(days: Int, today: Date) -> (start: String, end: String) {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        return (DateFormatting.dayString(start), DateFormatting.dayString(today))
    }

    /// recordDate 为 yyyy-MM-dd，字典序即时间序（与 Web/Android 一致）
    private static func inWindow(_ recordDate: String, _ start: String, _ end: String) -> Bool {
        recordDate >= start && recordDate <= end
    }

    static func hasEmotionData(_ emotions: [EmotionRecord], days: Int,
                               today: Date = Date()) -> Bool {
        let (start, end) = window(days: days, today: today)
        return emotions.contains { inWindow($0.recordDate, start, end) }
    }

    /// 返回窗口内每天的平均情绪值（yyyy-MM-dd, 均值）；当日无记录为 nil。
    /// 均值保留两位小数，口径对齐 Kotlin Math.round（half-up）：
    /// (value * 100 + 0.5).rounded(.down) / 100；Swift `.rounded()` 是
    /// half-away-from-zero，负均值（如 -0.125）会与 Android 差 0.01。
    static func dailyAverages(_ emotions: [EmotionRecord], days: Int,
                              today: Date = Date()) -> [(date: String, average: Double?)] {
        let (start, end) = window(days: days, today: today)
        var grouped: [String: [Int]] = [:]
        for emotion in emotions where inWindow(emotion.recordDate, start, end) {
            grouped[emotion.recordDate, default: []].append(emotion.level.rawValue)
        }
        let calendar = Calendar(identifier: .gregorian)
        let startDate = DateFormatting.parseDay(start)!
        return (0..<days).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let key = DateFormatting.dayString(date)
            let average = grouped[key].map { values in
                (Double(values.reduce(0, +)) / Double(values.count) * 100 + 0.5).rounded(.down) / 100
            }
            return (date: key, average: average)
        }
    }

    /// 按给定日期数组对齐输出每日均值（与 days 一一对应），当日无记录为 nil。
    /// 舍入口径同 dailyAverages(_:days:today:)，对齐 Kotlin Math.round。
    static func dailyAverages(_ emotions: [EmotionRecord], onDays days: [String]) -> [Double?] {
        let daySet = Set(days)
        var grouped: [String: [Int]] = [:]
        for emotion in emotions where daySet.contains(emotion.recordDate) {
            grouped[emotion.recordDate, default: []].append(emotion.level.rawValue)
        }
        return days.map { day in
            grouped[day].map { values in
                (Double(values.reduce(0, +)) / Double(values.count) * 100 + 0.5).rounded(.down) / 100
            }
        }
    }

    /// 负面情绪子类型（伤心/生气/难受）在时间窗内的分布，key 为中文名。
    static func subEmotionDistribution(_ emotions: [EmotionRecord], days: Int,
                                       today: Date = Date()) -> [(name: String, count: Int)] {
        let (start, end) = window(days: days, today: today)
        var counts: [String: Int] = [:]
        for emotion in emotions
        where emotion.level.isNegative && emotion.subEmotion != nil
            && inWindow(emotion.recordDate, start, end) {
            counts[emotion.subEmotion!.displayName, default: 0] += 1
        }
        return counts.map { (name: $0.key, count: $0.value) }
    }
}
