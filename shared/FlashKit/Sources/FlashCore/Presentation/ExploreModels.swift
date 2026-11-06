// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 记录页筛选胶囊（全部 / 日志 / 灵感 / 待整理）。「待整理」= 未改过分拣的日常日志
/// （category=log 且 colorTag=daily）。macOS 与 iOS 记录页共用。
public enum ExploreFilter: String, CaseIterable, Sendable {
    case all, log, idea, unsorted

    public var displayName: String {
        switch self {
        case .all: "全部"
        case .log: "日志"
        case .idea: "灵感"
        case .unsorted: "待整理"
        }
    }
}

/// 记录页筛选条件（标签 / 重要度 / 日期范围；类型由筛选胶囊承担）。
/// 空值表示不限；isActive 驱动「筛选」按钮高亮与空态「清除筛选」。
public struct ExploreCriteria: Equatable, Sendable {
    public var tag: ColorTag? = nil
    public var minImportance: Int = 0
    public var startDate: Date? = nil
    public var endDate: Date? = nil

    public init(tag: ColorTag? = nil, minImportance: Int = 0, startDate: Date? = nil, endDate: Date? = nil) {
        self.tag = tag
        self.minImportance = minImportance
        self.startDate = startDate
        self.endDate = endDate
    }

    public var isActive: Bool {
        tag != nil || minImportance > 0 || startDate != nil || endDate != nil
    }

    public mutating func clear() { self = ExploreCriteria() }
}

/// Idea→Task 转化草稿（PRD §18）：灵感内容预填为任务标题，sourceLogId 回写任务来源关联；
/// 原灵感保留不动。Identifiable 供 .sheet(item:) 承载。
public struct IdeaTaskDraft: Identifiable, Equatable, Sendable {
    /// 来源灵感 id（写入 TaskItem.sourceLogId）
    public let sourceLogId: String
    /// 预填标题（灵感内容）
    public let title: String
    public var id: String { sourceLogId }

    public init(sourceLogId: String, title: String) {
        self.sourceLogId = sourceLogId
        self.title = title
    }
}
