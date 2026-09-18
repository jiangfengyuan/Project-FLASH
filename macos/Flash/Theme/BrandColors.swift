// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import AppKit

/// 品牌/模块色。文本一律用 Color.primary/.secondary 语义色；
/// 这里的自定义色仅用于标签、情绪指示等点缀（spec §10.4）。
enum BrandColors {
    /// 跟随系统强调色（用户在系统设置改色后自动跟随）
    static let accent = Color(nsColor: .controlAccentColor)

    /// light/dark 双 hex 的动态色（spec §10.4 三变体中的前两个；
    /// 「增强对比度」由系统对语义色自动处理，自定义色保持简单）
    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }

    static func tagColor(_ tag: ColorTag) -> Color { tag.color }

    static func emotionColor(_ level: EmotionLevel) -> Color { level.color }

    // MARK: - Home 此刻页模块强调色（Aero PRD，低饱和柔和色）

    /// 日志模块：柔和紫
    static let logPurple = dynamic(light: "#8B7FD4", dark: "#A89FE0")

    /// 灵感模块：暖黄
    static let ideaYellow = dynamic(light: "#D9B36A", dark: "#E3C584")

    /// 任务模块：柔绿
    static let calendarGreen = dynamic(light: "#7FB38E", dark: "#93C6A3")

    /// 情绪模块：柔粉
    static let emotionPink = dynamic(light: "#D48FA8", dark: "#E0A7BC")

    // MARK: - 设计令牌（品牌标准 §03 中性色与表面，全端统一数值）

    /// 页面底色：浅色 #F7F9FA，深色用品牌标准深色 Surface #191A38
    static let pageBackground = dynamic(light: "#F7F9FA", dark: "#191A38")

    /// 实色卡片表面：浅色 #FFFFFF（表单/高密度列表用，不依赖玻璃模糊）；
    /// 深色用品牌弱表面 #3A3D5C
    static let cardSurface = dynamic(light: "#FFFFFF", dark: "#3A3D5C")

    /// 弱表面：次级卡片、分组
    static let weakSurface = dynamic(light: "#EDF0F5", dark: "#3A3D5C")

    /// 弱边界：分隔线与非关键边框。
    /// 深色取 #4A4E6E：与 cardSurface/weakSurface 的 #3A3D5C 保持同族（同色相提明度），
    /// 但又亮出一档——阶段一曾沿用 #3A3D5C，深色下边框与卡片表面同色导致不可见。
    static let weakBorder = dynamic(light: "#DFE6E9", dark: "#4A4E6E")

    /// 筛选 Chip 选中态：深墨实心 + 白字（跨端统一裁决，替代阶段一的品牌蓝紫）。
    /// 深色下用反色（近白底 + 深墨字），保证选中态在两种外观下都是「实心高对比」。
    static let chipSelectedBackground = dynamic(light: "#2D3436", dark: "#F5F6FA")
    static let chipSelectedForeground = dynamic(light: "#FFFFFF", dark: "#2D3436")

    /// 主文字 #2D3436（常规文本仍优先用 Color.primary 语义色，
    /// 此令牌用于需要跨端精确对齐品牌色值的场景）
    static let textPrimary = dynamic(light: "#2D3436", dark: "#F5F6FA")

    /// 次文字 #636E72
    static let textSecondary = dynamic(light: "#636E72", dark: "#B2BEC3")

    /// 品牌主操作色：蓝紫语义 #6C5CE7（禁止硬编码荧光绿）；
    /// 深色下略提亮保证可读性
    static let brandPrimary = dynamic(light: "#6C5CE7", dark: "#8B80F0")
}
