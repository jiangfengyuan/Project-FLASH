// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct EmotionRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public var level: EmotionLevel
    public var subEmotion: SubEmotion?
    public var status: String?
    public var note: String?
    /// 情绪强度 1–5（备份分区 schema 2，可空）
    public var intensity: Int? = nil
    /// 收藏（备份分区 schema 2，可空）
    public var isFavorite: Bool? = nil
    public var recordDate: String  // yyyy-MM-dd
    public var createdAt: String   // ISO-8601

    public init(id: String, level: EmotionLevel, subEmotion: SubEmotion? = nil, status: String? = nil, note: String? = nil, intensity: Int? = nil, isFavorite: Bool? = nil, recordDate: String, createdAt: String) {
        self.id = id
        self.level = level
        self.subEmotion = subEmotion
        self.status = status
        self.note = note
        self.intensity = intensity
        self.isFavorite = isFavorite
        self.recordDate = recordDate
        self.createdAt = createdAt
    }
}
