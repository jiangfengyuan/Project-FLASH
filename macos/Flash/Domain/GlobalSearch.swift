// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 全局搜索命中类型（日志含灵感 / 情绪 / 任务）
enum SearchMatchKind: String, Equatable {
    case log, emotion, task

    /// 结果列表的类型徽章文案
    var displayName: String {
        switch self {
        case .log: "记录"
        case .emotion: "情绪"
        case .task: "任务"
        }
    }
}

/// 全局搜索命中条目（日志 / 情绪 / 任务统一模型）
struct SearchMatch: Equatable {
    let id: String
    let kind: SearchMatchKind
    let title: String
    let createdAt: String
}

/// 全局搜索（对应 Android/Web 的 ⌘K 搜索）：大小写不敏感，
/// 日志同时匹配正文与标签中文名（对齐探索页搜索口径），任务匹配标题与备注，
/// 合并三类后按 createdAt 倒序取前 limit 条。
/// createdAt 为同格式 ISO-8601，字典序即时间序。
enum GlobalSearch {
    static func search(logs: [LogItem], emotions: [EmotionRecord], tasks: [TaskItem] = [],
                       query: String, limit: Int = 20) -> [SearchMatch] {
        let logMatches = logs
            .filter {
                $0.content.localizedCaseInsensitiveContains(query) ||
                    $0.colorTag.displayName.localizedCaseInsensitiveContains(query)
            }
            .map { SearchMatch(id: $0.id, kind: .log,
                               title: $0.content, createdAt: $0.createdAt) }
        // 标题：emoji + 备注，无备注时用情绪中文名；compactMap 单遍完成构造与匹配
        let emotionMatches = emotions.compactMap { emotion -> SearchMatch? in
            let title = "\(emotion.level.emoji) \(emotion.note ?? emotion.level.displayName)"
            guard title.localizedCaseInsensitiveContains(query) else { return nil }
            return SearchMatch(id: emotion.id, kind: .emotion,
                               title: title, createdAt: emotion.createdAt)
        }
        let taskMatches = tasks
            .filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                    ($0.notes?.localizedCaseInsensitiveContains(query) ?? false)
            }
            .map { SearchMatch(id: $0.id, kind: .task,
                               title: $0.title, createdAt: $0.createdAt) }
        let merged = logMatches + emotionMatches + taskMatches
        return Array(merged.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}
