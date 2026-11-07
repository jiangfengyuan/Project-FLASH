// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 系统搜索（iOS Core Spotlight）里的一条记录：纯值映射，平台层再转成 `CSSearchableItem`。
/// 只收日志与灵感；情绪与任务不进系统索引。
public struct SpotlightRecord: Equatable, Sendable {
    public static let titleLimit = 60
    public static let descriptionLimit = 300

    /// 即记录 id：结果回跳与删除都按它
    public let id: String
    /// `log` / `idea`：按分区批量删除时用
    public let domain: String
    public let title: String
    /// 首行之后的正文摘录；只有一行时为 nil
    public let contentDescription: String?
    public let keywords: [String]
    public let createdAt: Date?

    public init(_ log: LogItem) {
        id = log.id
        domain = log.category.rawValue
        let lines = log.content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        title = Self.clipped(lines.first ?? log.content, to: Self.titleLimit)
        let rest = lines.dropFirst().joined(separator: " ")
        contentDescription = rest.isEmpty ? nil : Self.clipped(rest, to: Self.descriptionLimit)
        keywords = [log.category == .idea ? L("灵感") : L("日志"), log.colorTag.displayName]
        createdAt = DateFormatting.parseISO(log.createdAt)
    }

    static func clipped(_ text: String, to limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }
}
