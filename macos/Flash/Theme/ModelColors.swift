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
}

extension EmotionLevel {
    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}

extension SubEmotion {
    /// 跟随系统外观的动态色（light/dark 双变体）
    var color: Color { BrandColors.dynamic(light: colorHex, dark: darkColorHex) }
}
