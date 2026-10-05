// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct EmotionRecord: Identifiable, Equatable {
    let id: String
    var level: EmotionLevel
    var subEmotion: SubEmotion?
    var status: String?
    var note: String?
    /// 情绪强度 1–5（备份分区 schema 2，可空）
    var intensity: Int? = nil
    /// 收藏（备份分区 schema 2，可空）
    var isFavorite: Bool? = nil
    var recordDate: String  // yyyy-MM-dd
    var createdAt: String   // ISO-8601
}
