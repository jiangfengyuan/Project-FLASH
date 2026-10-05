// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct LogItem: Identifiable, Equatable {
    let id: String
    var content: String
    var colorTag: ColorTag
    var category: Category
    var importance: Int
    /// 收藏（备份分区 schema 2，可空；缺省视为未收藏）
    var isFavorite: Bool? = nil
    var createdAt: String   // ISO-8601
    var recordDate: String  // yyyy-MM-dd
}
