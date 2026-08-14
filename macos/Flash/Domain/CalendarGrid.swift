import Foundation

struct DayAggregate: Equatable {
    let date: String
    let logs: [LogItem]
    let emotions: [EmotionRecord]
}

/// 按 recordDate 聚合（对应 Android CalendarViewModel.aggregates）
func aggregateDay(logs: [LogItem], emotions: [EmotionRecord]) -> [String: DayAggregate] {
    let dates = Set(logs.map(\.recordDate) + emotions.map(\.recordDate))
    var result: [String: DayAggregate] = [:]
    for date in dates {
        result[date] = DayAggregate(
            date: date,
            logs: logs.filter { $0.recordDate == date },
            emotions: emotions.filter { $0.recordDate == date }
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
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
