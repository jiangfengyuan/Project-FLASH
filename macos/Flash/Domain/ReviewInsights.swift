// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 回顾页洞察结论：当前时间窗口 vs 前一等长窗口的记录活跃度与情绪均值对比。
/// 纯函数、无 UI 依赖；recordDate 为 yyyy-MM-dd，字典序即时间序（与 EmotionStats 同口径）。
enum ReviewInsights {

    struct Comparison: Equatable {
        enum ActivityTrend: String, Equatable { case more, same, less }
        enum MoodTrend: String, Equatable { case better, same, lower, unknown }

        /// 当前窗口记录条数（日志 + 灵感 + 情绪合计）
        let currentCount: Int
        /// 前一等长窗口记录条数
        let previousCount: Int
        /// 当前窗口情绪均值（-3~+3，窗口内无情绪记录为 nil）
        let currentEmotionAverage: Double?
        /// 前一等长窗口情绪均值
        let previousEmotionAverage: Double?
        let activityTrend: ActivityTrend
        let moodTrend: MoodTrend
        /// 两窗口合计记录 >= minimumEntries 才下趋势结论，避免数据不足时误导
        let hasEnoughData: Bool
        /// 首行结论文案；数据不足时为温和引导而非强行结论
        let conclusion: String
    }

    /// 数据量下限：两窗口合计少于此数不下结论
    static let minimumEntries = 5
    /// 情绪均值变化显著阈值（-3~+3 量表）
    static let moodChangeThreshold = 0.5

    static func compare(logs: [LogItem], emotions: [EmotionRecord],
                        window: ReviewWindow, today: Date = Date()) -> Comparison {
        let days = window.days(today: today)
        let calendar = Calendar(identifier: .gregorian)
        let currentStart = calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: currentStart)!
        let previousStart = calendar.date(byAdding: .day, value: -(days - 1), to: previousEnd)!
        let current = (start: DateFormatting.dayString(currentStart),
                       end: DateFormatting.dayString(today))
        let previous = (start: DateFormatting.dayString(previousStart),
                        end: DateFormatting.dayString(previousEnd))

        let currentLogs = logs.filter { inRange($0.recordDate, current) }
        let previousLogs = logs.filter { inRange($0.recordDate, previous) }
        let currentEmotions = emotions.filter { inRange($0.recordDate, current) }
        let previousEmotions = emotions.filter { inRange($0.recordDate, previous) }

        let currentCount = currentLogs.count + currentEmotions.count
        let previousCount = previousLogs.count + previousEmotions.count
        let currentAverage = average(of: currentEmotions)
        let previousAverage = average(of: previousEmotions)

        let activityTrend: Comparison.ActivityTrend =
            currentCount > previousCount ? .more : (currentCount < previousCount ? .less : .same)
        let moodTrend: Comparison.MoodTrend
        if let currentAverage, let previousAverage {
            let delta = currentAverage - previousAverage
            moodTrend = delta >= moodChangeThreshold ? .better
                : (delta <= -moodChangeThreshold ? .lower : .same)
        } else {
            moodTrend = .unknown
        }

        let hasEnoughData = currentCount + previousCount >= minimumEntries
        let labels = labels(for: window)
        let conclusion: String
        if !hasEnoughData {
            conclusion = "继续记录，回顾会慢慢清晰"
        } else {
            var text: String
            switch activityTrend {
            case .more: text = "\(labels.current)你记录得比\(labels.previous)更频繁"
            case .less: text = "\(labels.current)的记录不如\(labels.previous)活跃"
            case .same: text = "\(labels.current)的记录与\(labels.previous)持平"
            }
            switch moodTrend {
            case .better: text += "，情绪整体更好一些"
            case .lower: text += "，情绪整体更低落一些"
            case .same, .unknown: break
            }
            conclusion = text
        }

        return Comparison(currentCount: currentCount, previousCount: previousCount,
                          currentEmotionAverage: currentAverage,
                          previousEmotionAverage: previousAverage,
                          activityTrend: activityTrend, moodTrend: moodTrend,
                          hasEnoughData: hasEnoughData, conclusion: conclusion)
    }

    private static func labels(for window: ReviewWindow) -> (current: String, previous: String) {
        switch window {
        case .week: return ("这周", "上周")
        case .month: return ("这个月", "上个月")
        case .days30: return ("近 30 天", "之前 30 天")
        case .days90: return ("近 90 天", "之前 90 天")
        }
    }

    private static func inRange(_ recordDate: String,
                                _ range: (start: String, end: String)) -> Bool {
        recordDate >= range.start && recordDate <= range.end
    }

    /// 舍入口径对齐 EmotionStats.dailyAverages：Kotlin Math.round 风格 half-up
    private static func average(of emotions: [EmotionRecord]) -> Double? {
        guard !emotions.isEmpty else { return nil }
        let mean = Double(emotions.reduce(0) { $0 + $1.level.rawValue }) / Double(emotions.count)
        return (mean * 100 + 0.5).rounded(.down) / 100
    }
}
