// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum LogSort: String, CaseIterable {
    case newest, oldest, tag

    var displayName: String {
        switch self {
        case .newest: "最新"
        case .oldest: "最早"
        case .tag: "按标签"
        }
    }
}

/// 对应 Web 版 LogFlow 页 + logFilters.ts / Android LogFlowViewModel.applyFilter
struct LogFilter: Equatable {
    var query: String = ""
    var tags: Set<ColorTag> = []
    var startDate: String? = nil // yyyy-MM-dd，含当天
    var endDate: String? = nil
    var sort: LogSort = .newest
    /// 只看收藏（isFavorite 为可选三态，nil/false 均视为未收藏）
    var favoritesOnly: Bool = false

    func apply(to logs: [LogItem]) -> [LogItem] {
        let lowercasedQuery = query.lowercased()
        let filtered = logs.filter { log in
            guard log.category == .log else { return false }
            let matchesSearch = lowercasedQuery.isEmpty
                || log.content.lowercased().contains(lowercasedQuery)
            let matchesTags = tags.isEmpty || tags.contains(log.colorTag)
            // recordDate 为 yyyy-MM-dd，字典序即时间序
            let matchesStart = startDate == nil || log.recordDate >= startDate!
            let matchesEnd = endDate == nil || log.recordDate <= endDate!
            let matchesFavorite = !favoritesOnly || log.isFavorite == true
            return matchesSearch && matchesTags && matchesStart && matchesEnd && matchesFavorite
        }
        switch sort {
        case .tag: return filtered.sorted { $0.colorTag.rawValue < $1.colorTag.rawValue }
        case .oldest: return filtered.sorted { $0.createdAt < $1.createdAt }
        case .newest: return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
