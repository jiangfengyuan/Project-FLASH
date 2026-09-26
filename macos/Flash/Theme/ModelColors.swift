// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// A4：Models 层只保存 hex 纯数据（三端互通的存储色），SwiftUI Color 换算集中在 Theme。
/// 以下扩展保持与历史实现完全相同的 `color` API 与色值来源（colorHex/darkColorHex），
/// 所有 View 与测试无需改动。
extension ColorTag {
    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }

    /// 标签色用于小号文字（徽章文案、重要度标记）时的可读变体：
    /// 存储色多为高亮点缀色（如 #FFD93D），浅色模式下直接作文字远低于 4.5:1，
    /// 故浅色取同色系加深值，深色沿用 darkColorHex（深底下本身可读）。
    var textColor: Color { BrandColors.dynamic(light: textColorHex, dark: darkColorHex) }

    /// 浅色外观下的文字用色（同色相加深，白底 ≥ 4.5:1）
    private var textColorHex: String {
        switch self {
        case .urgent: "#C43D3D"
        case .inspiration: "#8A6D00"
        case .daily: "#2F6BD0"
        case .memo: "#3A8545"
        case .emotion: "#7A3E93"
        case .idea: "#B46300"
        }
    }
}

extension EmotionLevel {
    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}

extension SubEmotion {
    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}
