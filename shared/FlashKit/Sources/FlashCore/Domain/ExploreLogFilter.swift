// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 记录页（Explore）内存过滤条件：关键词 + 类别集合 + 标签 + 重要度 + 日期范围 + 仅收藏。
/// 由 ExploreResultsView 的私有 displayedLogs 过滤下沉而来（消除视图内第三套过滤实现）。
/// 视图中类别已由 @Query 谓词在 DB 层先筛时传 categories = nil；集合过滤保留给
/// 完整内存路径与测试。排序不在此进行（调用方保证，记录页为 createdAt 倒序）。
public struct ExploreLogFilter: Equatable, Sendable {
    /// 关键词：命中正文或标签中文名（与 GlobalSearch / 原 displayedLogs 同口径）
    public var query: String = ""
    /// 类别集合；nil = 不限
    public var categories: Set<Category>? = nil
    public var tag: ColorTag? = nil
    public var minImportance: Int = 0
    public var startDate: String? = nil // yyyy-MM-dd，含当天
    public var endDate: String? = nil
    /// 只看收藏（isFavorite 为可选三态，nil/false 均视为未收藏）
    public var favoritesOnly: Bool = false

    public var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || categories != nil || tag != nil || minImportance > 0
            || startDate != nil || endDate != nil || favoritesOnly
    }

    public func apply(to logs: [LogItem]) -> [LogItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return logs.filter { log in
            if let categories, !categories.contains(log.category) { return false }
            if favoritesOnly && log.isFavorite != true { return false }
            if !normalized.isEmpty,
               !log.content.lowercased().contains(normalized),
               !log.colorTag.displayName.lowercased().contains(normalized) { return false }
            if let tag, log.colorTag != tag { return false }
            if minImportance > 0, log.importance < minImportance { return false }
            // recordDate 为 yyyy-MM-dd，字典序即时间序
            if let startDate, log.recordDate < startDate { return false }
            if let endDate, log.recordDate > endDate { return false }
            return true
        }
    }

    public init(query: String = "", categories: Set<Category>? = nil, tag: ColorTag? = nil, minImportance: Int = 0, startDate: String? = nil, endDate: String? = nil, favoritesOnly: Bool = false) {
        self.query = query
        self.categories = categories
        self.tag = tag
        self.minImportance = minImportance
        self.startDate = startDate
        self.endDate = endDate
        self.favoritesOnly = favoritesOnly
    }
}
