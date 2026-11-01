// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// iOS「暖调手作」主题色值（品牌标准 §08 登记）：纸张米白 + 暖墨 + 陶土强调，深色为浓缩咖啡底。
///
/// 只存 hex 数据、不做条件编译：iOS 端 `BrandColors` 在 `#if os(iOS)` 分支引用这里的值，
/// macOS 宿主的测试也能直接校验对比度（WarmPaletteTests）。macOS 外观不受影响。
public enum WarmPalette {
    public struct Pair: Sendable {
        public let light: String
        public let dark: String

        public init(light: String, dark: String) {
            self.light = light
            self.dark = dark
        }
    }

    // MARK: - 中性色与表面

    /// 纸张底 / 浓缩咖啡底
    public static let pageBackground = Pair(light: "#F6F1E8", dark: "#1E1A17")
    /// 卡片：暖白纸 / 深咖啡
    public static let cardSurface = Pair(light: "#FFFCF6", dark: "#2A2420")
    /// 弱表面：燕麦色 / 次深咖啡
    public static let weakSurface = Pair(light: "#EFE7DA", dark: "#342D28")
    /// 弱边界：浅陶 / 咖啡边
    public static let weakBorder = Pair(light: "#E2D6C4", dark: "#4A4039")
    /// 主文字：暖墨
    public static let textPrimary = Pair(light: "#2B2420", dark: "#F3ECE2")
    /// 次文字：暖灰褐
    public static let textSecondary = Pair(light: "#6B5E54", dark: "#B9AC9F")

    // MARK: - 强调色

    /// 陶土主操作色。浅色在燕麦弱表面上仍 ≥ 4.5:1；深色提亮为浅陶，作文字/图标
    public static let brandPrimary = Pair(light: "#A24B2B", dark: "#E08A6A")
    /// 陶土实心底上的文字/图标：浅色用纸白，深色（浅陶底）用暖墨
    public static let onBrandPrimary = Pair(light: "#FFFCF6", dark: "#2B2420")
    /// 筛选 Chip 选中态：墨色实心 + 纸白字（深色反转）
    public static let chipSelectedBackground = Pair(light: "#2B2420", dark: "#F3ECE2")
    public static let chipSelectedForeground = Pair(light: "#FFFCF6", dark: "#2B2420")

    // MARK: - 模块色（大地色系，仅作图标/点缀，不作正文）

    /// 日志：梅子紫
    public static let logPurple = Pair(light: "#8A6A9E", dark: "#B79BC9")
    /// 灵感：赭黄
    public static let ideaYellow = Pair(light: "#C99A45", dark: "#DDB36A")
    /// 灵感黄的小号文字可读变体
    public static let ideaYellowText = Pair(light: "#7A5715", dark: "#DDB36A")
    /// 任务：鼠尾草绿
    public static let calendarGreen = Pair(light: "#76946F", dark: "#9DB894")
    /// 可访问绿：文字与图标
    public static let accessibleGreen = Pair(light: "#467040", dark: "#A3C69A")
    /// 情绪：玫瑰陶
    public static let emotionPink = Pair(light: "#C47E7E", dark: "#D9A0A0")

    // MARK: - 阴影

    /// 暖褐阴影色（浅色下替代纯黑，避免纸面发灰）；深色仍用黑
    public static let shadowTint = Pair(light: "#3B2A1E", dark: "#000000")
}
