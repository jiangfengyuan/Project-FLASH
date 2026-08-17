import Foundation

/// 全局搜索命中条目（日志 / 情绪统一模型）
struct SearchMatch: Equatable {
    let id: String
    let isEmotion: Bool
    let title: String
    let createdAt: String
}

/// 全局搜索（对应 Android/Web 的 ⌘K 搜索）：大小写不敏感，
/// 合并日志与情绪后按 createdAt 倒序取前 limit 条。
/// createdAt 为同格式 ISO-8601，字典序即时间序。
enum GlobalSearch {
    static func search(logs: [LogItem], emotions: [EmotionRecord],
                       query: String, limit: Int = 20) -> [SearchMatch] {
        let logMatches = logs
            .filter { $0.content.localizedCaseInsensitiveContains(query) }
            .map { SearchMatch(id: $0.id, isEmotion: false,
                               title: $0.content, createdAt: $0.createdAt) }
        // 标题：emoji + 备注，无备注时用情绪中文名；compactMap 单遍完成构造与匹配
        let emotionMatches = emotions.compactMap { emotion -> SearchMatch? in
            let title = "\(emotion.level.emoji) \(emotion.note ?? emotion.level.displayName)"
            guard title.localizedCaseInsensitiveContains(query) else { return nil }
            return SearchMatch(id: emotion.id, isEmotion: true,
                               title: title, createdAt: emotion.createdAt)
        }
        let merged = logMatches + emotionMatches
        return Array(merged.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}
