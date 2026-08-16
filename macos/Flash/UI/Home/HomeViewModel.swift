import Foundation

/// Home 仪表盘的数据装配层：注入 logs/emotions/today，集中计算今日概览、
/// 最近动态、搜索结果、情绪快照与本周洞察。仅在注入数据变化时重算，
/// 避免视图每次 body 求值（如搜索/草稿按键）都全量分组统计。
/// 不依赖 SwiftUI，可直接构造注入数据单测。
///
/// 时间线/搜索条目的时刻经 DateFormatting.localTime 转本地 HH:mm
/// （createdAt 是 UTC ISO-8601，直接截子串会把 UTC 时刻当本地时间显示）。
@Observable
final class HomeViewModel {

    /// 「情绪快照」卡片的装配数据
    struct EmotionSnapshot {
        let emoji: String
        let title: String
        let summary: String
        /// 周一到周日每天的情绪均值（0–6 标尺），无数据为 nil
        let points: [Double?]
    }

    /// 「本周洞察」卡片的装配数据
    struct WeekInsight {
        let headline: String
        let detail: String
        let trend: [Double]
    }

    // MARK: - 注入数据

    private(set) var logs: [LogItem]
    private(set) var emotions: [EmotionRecord]
    /// 日期窗口（本周 / 近 7 天）的基准时刻
    private(set) var today: Date
    /// today 对应的本地 yyyy-MM-dd（与 recordDate 比较用，字典序即时间序）
    private(set) var todayString: String

    // MARK: - 派生数据（仅 update 时重算，视图直接读取）

    /// 「今日概览」统计卡（log / idea / emotion）
    private(set) var overviewStats: [OverviewStat] = []
    /// 「今天」的 Log 与 Emotion 合并，按 createdAt 倒序取前 6 条
    private(set) var recentEntries: [ActivityEntry] = []
    private(set) var emotionSnapshot: EmotionSnapshot
    private(set) var weekInsight: WeekInsight?

    /// 无情绪记录时的占位快照
    private static let placeholderSnapshot = EmotionSnapshot(
        emoji: "🙂", title: "还没有记录", summary: "记录第一条情绪吧",
        points: Array(repeating: nil, count: 7))

    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

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
        overviewStats = makeOverviewStats()
        recentEntries = makeRecentEntries()
        emotionSnapshot = makeEmotionSnapshot()
        weekInsight = makeWeekInsight()
    }

    // MARK: - 搜索（由防抖后的查询词驱动，随调随算）

    /// 全局搜索（走 GlobalSearch 统一入口），按 createdAt 倒序取前 limit 条；
    /// tag 放记录日期（结果跨多天，仅时分不足以定位）
    func searchResultEntries(query: String, limit: Int = 20) -> [ActivityEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return GlobalSearch.search(logs: logs, emotions: emotions, query: query, limit: limit)
            .map { match in
                if match.isEmotion {
                    return ActivityEntry(
                        id: "emotion-\(match.id)",
                        time: DateFormatting.localTime(fromISO: match.createdAt),
                        module: .emotion,
                        title: match.title,
                        tag: emotions.first { $0.id == match.id }?.recordDate)
                }
                let log = logs.first { $0.id == match.id }
                return ActivityEntry(
                    id: "log-\(match.id)",
                    time: DateFormatting.localTime(fromISO: match.createdAt),
                    module: log?.category == .idea ? .idea : .log,
                    title: match.title,
                    tag: log?.recordDate)
            }
    }

    // MARK: - 今日概览

    private var todayLogs: [LogItem] { logs.filter { $0.recordDate == todayString && $0.category == .log } }
    private var todayIdeas: [LogItem] { logs.filter { $0.recordDate == todayString && $0.category == .idea } }

    private func makeOverviewStats() -> [OverviewStat] {
        let latestEmotion = emotions.first
        return [
            OverviewStat(module: .log,
                         valueText: String(format: "%02d", todayLogs.count),
                         title: "Logs",
                         trend: dailyLogCounts(category: .log)),
            OverviewStat(module: .idea,
                         valueText: String(format: "%02d", todayIdeas.count),
                         title: "Ideas",
                         trend: dailyLogCounts(category: .idea)),
            OverviewStat(module: .emotion,
                         valueText: latestEmotion?.level.emoji ?? "🙂",
                         title: latestEmotion?.level.displayName ?? "还没有记录",
                         trend: emotionSparklineTrend()),
        ]
    }

    /// 近 N 天（含今天）每天的 log/idea 数量，按时间升序
    private func dailyLogCounts(category: Category, days: Int = 7) -> [Double] {
        let dayStrings = DateWindows.lastNDays(days, today: today)
        var counts: [String: Int] = [:]
        for log in logs where log.category == category {
            counts[log.recordDate, default: 0] += 1
        }
        return dayStrings.map { Double(counts[$0] ?? 0) }
    }

    /// 近 7 天情绪均值（level.rawValue -3...3 平移到 0–6；无数据天补 0，固定 7 根柱）。
    /// SparklineView 为非负设计，全负的原始均值会被归一化成 7 根等高占位柱，故平移补齐。
    private func emotionSparklineTrend() -> [Double] {
        EmotionStats.dailyAverages(emotions, onDays: DateWindows.lastNDays(7, today: today))
            .map { $0.map { $0 + 3 } ?? 0 }
    }

    // MARK: - 最近动态

    private func makeRecentEntries() -> [ActivityEntry] {
        var pairs: [(createdAt: String, entry: ActivityEntry)] = []
        for log in logs where log.recordDate == todayString {
            pairs.append((log.createdAt, ActivityEntry(
                id: "log-\(log.id)",
                time: DateFormatting.localTime(fromISO: log.createdAt),
                module: log.category == .idea ? .idea : .log,
                title: log.content,
                tag: nil)))
        }
        for emotion in emotions where emotion.recordDate == todayString {
            pairs.append((emotion.createdAt, ActivityEntry(
                id: "emotion-\(emotion.id)",
                time: DateFormatting.localTime(fromISO: emotion.createdAt),
                module: .emotion,
                title: "\(emotion.level.emoji) \(emotion.note ?? emotion.level.displayName)",
                tag: nil)))
        }
        return pairs
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(6)
            .map { $0.entry }
    }

    // MARK: - 情绪快照

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
    /// 经 EmotionStats.dailyAverages(onDays:) 按周一到周日对齐（原滚动窗口与周视图不对齐）。
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

    // MARK: - 本周洞察

    /// 本周（周一到周日）logs+emotions 每天计数，找最活跃的一天；全无数据返回 nil（卡片不显示）
    private func makeWeekInsight() -> WeekInsight? {
        let keys = DateWindows.currentWeek(today: today)
        var counts: [String: Int] = [:]
        for log in logs { counts[log.recordDate, default: 0] += 1 }
        for emotion in emotions { counts[emotion.recordDate, default: 0] += 1 }
        let trend = keys.map { Double(counts[$0] ?? 0) }
        guard trend.contains(where: { $0 > 0 }) else { return nil }
        let maxIndex = trend.indices.max(by: { trend[$0] < trend[$1] })!
        return WeekInsight(headline: "周\(Self.weekdayLabels[maxIndex])是你最活跃的一天。",
                           detail: "继续保持！",
                           trend: trend)
    }
}
