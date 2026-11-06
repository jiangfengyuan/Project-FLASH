// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct LogItem: Identifiable, Equatable, Sendable {
    public let id: String
    public var content: String
    public var colorTag: ColorTag
    public var category: Category
    public var importance: Int
    /// 收藏（备份分区 schema 2，可空；缺省视为未收藏）
    public var isFavorite: Bool? = nil
    public var createdAt: String   // ISO-8601
    public var recordDate: String  // yyyy-MM-dd

    public init(id: String, content: String, colorTag: ColorTag, category: Category, importance: Int, isFavorite: Bool? = nil, createdAt: String, recordDate: String) {
        self.id = id
        self.content = content
        self.colorTag = colorTag
        self.category = category
        self.importance = importance
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.recordDate = recordDate
    }
}
