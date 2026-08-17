// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 与 Web 版 src/lib/constants.ts 对齐。rawValue 即 storageKey，保证三端数据互通。
/// 纯数据模型：仅保存 hex 色值字符串，SwiftUI Color 换算见 Theme/ModelColors.swift（A4）。
enum ColorTag: String, CaseIterable, Codable {
    case urgent, inspiration, daily, memo, emotion, idea

    var displayName: String {
        switch self {
        case .urgent: "紧急"
        case .inspiration: "灵感"
        case .daily: "日常"
        case .memo: "备忘"
        case .emotion: "情绪"
        case .idea: "想法"
        }
    }

    /// light 外观色值（与 Web/Android 互通的存储色）
    var colorHex: String {
        switch self {
        case .urgent: "#FF6B6B"
        case .inspiration: "#FFD93D"
        case .daily: "#4D96FF"
        case .memo: "#6BCB77"
        case .emotion: "#9B59B6"
        case .idea: "#FF9F43"
        }
    }

    /// dark 外观色值
    var darkColorHex: String {
        switch self {
        case .urgent: "#FF8585"
        case .inspiration: "#C9A227"
        case .daily: "#6BA8FF"
        case .memo: "#82D18E"
        case .emotion: "#B578D1"
        case .idea: "#FFB268"
        }
    }
}
