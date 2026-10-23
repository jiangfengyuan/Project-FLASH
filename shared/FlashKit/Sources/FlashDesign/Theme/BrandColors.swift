// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
// iOS：SwiftUI 没有「代码内定义 light/dark 双值」的 Color API（只能走 Asset Catalog），
// 动态色必须经 UIColor(dynamicProvider:)；这是 iOS 端唯一的 UIKit 依赖。
import UIKit
#endif

/// 品牌/模块色。文本一律用 Color.primary/.secondary 语义色；
/// 这里的自定义色仅用于标签、情绪指示等点缀（spec §10.4）。
public enum BrandColors {
    /// 跟随系统强调色（用户在系统设置改色后自动跟随）
    #if canImport(AppKit)
    public static let accent = Color(nsColor: .controlAccentColor)
    #else
    public static let accent = Color.accentColor
    #endif

    /// 平台语义色：控件底（GlassCard 表面）。macOS controlBackgroundColor ↔ iOS secondarySystemBackground
    #if canImport(AppKit)
    public static let systemControlBackground = Color(nsColor: .controlBackgroundColor)
    #else
    public static let systemControlBackground = Color(uiColor: .secondarySystemBackground)
    #endif

    /// 平台语义色：破坏性/错误提示红。macOS systemRed ↔ iOS systemRed
    #if canImport(AppKit)
    public static let destructive = Color(nsColor: .systemRed)
    #else
    public static let destructive = Color(uiColor: .systemRed)
    #endif

    /// 平台语义色：选中内容底（日历选中日）。macOS selectedContentBackgroundColor ↔ iOS tintColor 同系
    #if canImport(AppKit)
    public static let selectedContentBackground = Color(nsColor: .selectedContentBackgroundColor)
    #else
    public static let selectedContentBackground = Color.accentColor
    #endif

    /// 平台语义色：分隔线。macOS separatorColor ↔ iOS separator
    #if canImport(AppKit)
    public static let systemSeparator = Color(nsColor: .separatorColor)
    #else
    public static let systemSeparator = Color(uiColor: .separator)
    #endif

    /// light/dark 双 hex 的动态色（spec §10.4 三变体中的前两个；
    /// 「增强对比度」由系统对语义色自动处理，自定义色保持简单）
    public static func dynamic(light: String, dark: String) -> Color {
        #if canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #endif
    }

    public static func tagColor(_ tag: ColorTag) -> Color { tag.color }

    public static func emotionColor(_ level: EmotionLevel) -> Color { level.color }

    // MARK: - Home 此刻页模块强调色（Aero PRD，低饱和柔和色）

    /// 日志模块：柔和紫
    public static let logPurple = dynamic(light: "#8B7FD4", dark: "#A89FE0")

    /// 灵感模块：暖黄
    public static let ideaYellow = dynamic(light: "#D9B36A", dark: "#E3C584")

    /// 灵感黄用于小号文字（选中胶囊文案等）的可读变体：
    /// 浅色下同色系加深（白底 ≥ 4.5:1），深色沿用浅黄（深底可读）
    public static let ideaYellowText = dynamic(light: "#8C6A1D", dark: "#E3C584")

    /// 任务模块：柔绿
    public static let calendarGreen = dynamic(light: "#7FB38E", dark: "#93C6A3")

    /// 情绪模块：柔粉
    public static let emotionPink = dynamic(light: "#D48FA8", dark: "#E0A7BC")

    // MARK: - 设计令牌（品牌标准 §03 中性色与表面，全端统一数值）

    /// 页面底色：浅色 #F7F9FA，深色用品牌标准深色 Surface #191A38
    public static let pageBackground = dynamic(light: "#F7F9FA", dark: "#191A38")

    /// 实色卡片表面：浅色 #FFFFFF（表单/高密度列表用，不依赖玻璃模糊）；
    /// 深色用品牌弱表面 #3A3D5C
    public static let cardSurface = dynamic(light: "#FFFFFF", dark: "#3A3D5C")

    /// 弱表面：次级卡片、分组
    public static let weakSurface = dynamic(light: "#EDF0F5", dark: "#3A3D5C")

    /// 弱边界：分隔线与非关键边框。
    /// 深色取 #4A4E6E：与 cardSurface/weakSurface 的 #3A3D5C 保持同族（同色相提明度），
    /// 但又亮出一档——阶段一曾沿用 #3A3D5C，深色下边框与卡片表面同色导致不可见。
    public static let weakBorder = dynamic(light: "#DFE6E9", dark: "#4A4E6E")

    /// 筛选 Chip 选中态：深墨实心 + 白字（跨端统一裁决，替代阶段一的品牌蓝紫）。
    /// 深色下用反色（近白底 + 深墨字），保证选中态在两种外观下都是「实心高对比」。
    public static let chipSelectedBackground = dynamic(light: "#2D3436", dark: "#F5F6FA")
    public static let chipSelectedForeground = dynamic(light: "#FFFFFF", dark: "#2D3436")

    /// 主文字 #2D3436（常规文本仍优先用 Color.primary 语义色，
    /// 此令牌用于需要跨端精确对齐品牌色值的场景）
    public static let textPrimary = dynamic(light: "#2D3436", dark: "#F5F6FA")

    /// 次文字 #636E72
    public static let textSecondary = dynamic(light: "#636E72", dark: "#B2BEC3")

    /// 品牌主操作色：蓝紫语义 #6C5CE7（禁止硬编码荧光绿）；
    /// 深色下略提亮保证可读性
    public static let brandPrimary = dynamic(light: "#6C5CE7", dark: "#8B80F0")

    /// 可访问绿：任务/数据安全等「绿色语义」场景的文字与图标色。
    /// 系统 .green 浅色下在白底仅约 2.1:1，不满足图标/文字对比度；
    /// 此令牌浅色取深绿（白底 ≥ 4.5:1），深色取浅绿（深底 ≥ 4.5:1）。
    public static let accessibleGreen = dynamic(light: "#3A8545", dark: "#8FCE9F")
}
