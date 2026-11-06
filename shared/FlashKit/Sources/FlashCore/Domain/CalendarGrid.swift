// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct DayAggregate: Equatable, Sendable {
    public let date: String
    public let logs: [LogItem]
    public let emotions: [EmotionRecord]
    public let tasks: [TaskItem]

    public init(date: String, logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem]) {
        self.date = date
        self.logs = logs
        self.emotions = emotions
        self.tasks = tasks
    }
}

/// 按 recordDate 聚合（对应 Android CalendarViewModel.aggregates）
/// 单遍分组：Dictionary(grouping:) 各扫一遍，组内保持原数组顺序。
public func aggregateDay(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = []) -> [String: DayAggregate] {
    let logsByDay = Dictionary(grouping: logs, by: \.recordDate)
    let emotionsByDay = Dictionary(grouping: emotions, by: \.recordDate)
    let tasksByDay = Dictionary(grouping: tasks.compactMap { task in
        task.calendarDate.map { ($0, task) }
    }, by: \.0).mapValues { $0.map(\.1) }
    var result: [String: DayAggregate] = [:]
    result.reserveCapacity(logsByDay.count + emotionsByDay.count + tasksByDay.count)
    for date in Set(logsByDay.keys).union(emotionsByDay.keys).union(tasksByDay.keys) {
        result[date] = DayAggregate(
            date: date,
            logs: logsByDay[date] ?? [],
            emotions: emotionsByDay[date] ?? [],
            tasks: tasksByDay[date] ?? []
        )
    }
    return result
}

/// 月视图网格（对应 Android CalendarViewModel.buildWeeks）
public enum CalendarGrid: Sendable {
    /// 42 格（6 周 × 7 天），周一为一周起点，含前后月溢出天。
    public static func weeks(containing month: Date) -> [[Date]] {
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

    public static func monthString(_ date: Date) -> String {
        DateFormatting.monthString(date)
    }
}
