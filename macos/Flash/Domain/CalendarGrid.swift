// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct DayAggregate: Equatable {
    let date: String
    let logs: [LogItem]
    let emotions: [EmotionRecord]
}

/// 按 recordDate 聚合（对应 Android CalendarViewModel.aggregates）
/// 单遍分组：Dictionary(grouping:) 各扫一遍，组内保持原数组顺序。
func aggregateDay(logs: [LogItem], emotions: [EmotionRecord]) -> [String: DayAggregate] {
    let logsByDay = Dictionary(grouping: logs, by: \.recordDate)
    let emotionsByDay = Dictionary(grouping: emotions, by: \.recordDate)
    var result: [String: DayAggregate] = [:]
    result.reserveCapacity(logsByDay.count + emotionsByDay.count)
    for date in Set(logsByDay.keys).union(emotionsByDay.keys) {
        result[date] = DayAggregate(
            date: date,
            logs: logsByDay[date] ?? [],
            emotions: emotionsByDay[date] ?? []
        )
    }
    return result
}

/// 月视图网格（对应 Android CalendarViewModel.buildWeeks）
enum CalendarGrid {
    /// 42 格（6 周 × 7 天），周一为一周起点，含前后月溢出天。
    static func weeks(containing month: Date) -> [[Date]] {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: month)
        let first = calendar.date(from: components)!
        // weekday: 1=周日 2=周一 ... 7=周六 → 周一偏移 = (weekday + 5) % 7
        let startOffset = (calendar.component(.weekday, from: first) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -startOffset, to: first)!
        return (0..<6).map { week in
            (0..<7).map { day in
                calendar.date(byAdding: .day, value: week * 7 + day, to: start)!
            }
        }
    }

    static func monthString(_ date: Date) -> String {
        DateFormatting.monthString(date)
    }
}
