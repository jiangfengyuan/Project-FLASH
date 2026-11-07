// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// 「纸上书写」设计语言的 iOS 色值（品牌标准 §08）。唯一来源是 `docs/design/paper-tokens.json`，
/// 由 PaperPaletteTests 逐项核对；只存 hex 数据、不做条件编译，macOS 宿主也能跑对比度测试。
/// macOS 外观不受影响。
public enum PaperPalette {
    public struct Pair: Sendable {
        public let light: String
        public let dark: String

        public init(light: String, dark: String) {
            self.light = light
            self.dark = dark
        }
    }

    // MARK: - 中性色与表面

    public static let pageBackground = Pair(light: "#FFF9ED", dark: "#1F1A16")
    public static let cardSurface = Pair(light: "#FFFDF6", dark: "#2B2520")
    public static let weakSurface = Pair(light: "#F3EADA", dark: "#362E28")
    /// 羊皮纸：叠放底页、折角
    public static let parchment = Pair(light: "#EADFCB", dark: "#40372F")
    public static let weakBorder = Pair(light: "#E4D8C2", dark: "#4A4039")
    public static let textPrimary = Pair(light: "#2E2A26", dark: "#F4ECDF")
    public static let textSecondary = Pair(light: "#5E5044", dark: "#BFB2A3")
    public static let textTertiary = Pair(light: "#6B655E", dark: "#A89C8F")

    // MARK: - 强调色

    /// 柿橙：主操作、强调、文字
    public static let brandPrimary = Pair(light: "#A84A24", dark: "#E9926C")
    public static let onBrandPrimary = Pair(light: "#FFFDF6", dark: "#26201B")
    /// 柿橙亮：仅图标与装饰（≥ 3:1），不作文字
    public static let brandFill = Pair(light: "#D0683C", dark: "#E9926C")
    public static let chipSelectedBackground = Pair(light: "#2E2A26", dark: "#F4ECDF")
    public static let chipSelectedForeground = Pair(light: "#FFFDF6", dark: "#26201B")
    public static let destructive = Pair(light: "#A63A2E", dark: "#E89A8E")

    // MARK: - 模块色（图标 ≥ 3:1；文字用 *Text 变体 ≥ 4.5:1）

    public static let logPurple = Pair(light: "#8A6A9E", dark: "#B79BC9")
    public static let ideaYellow = Pair(light: "#A9812A", dark: "#DDB565")
    public static let ideaYellowText = Pair(light: "#7A5A12", dark: "#DDB565")
    public static let calendarGreen = Pair(light: "#74906B", dark: "#A6C09C")
    public static let accessibleGreen = Pair(light: "#55714F", dark: "#A6C09C")
    public static let emotionPink = Pair(light: "#B47A80", dark: "#D9A5A8")
    public static let emotionPinkText = Pair(light: "#9C5560", dark: "#D9A5A8")

    // MARK: - 阴影与遮罩（任何外观都不用纯黑）

    public static let shadowTint = Pair(light: "#3B2A1E", dark: "#120D0A")
    public static let scrim = Pair(light: "#3B2A1E", dark: "#120D0A")

    // MARK: - 标签 / 情绪显示色（备份只存键名，改显示色不影响数据）

    public struct TagTone: Sendable {
        public let fill: Pair
        public let text: Pair
    }

    /// 键名与备份契约的 colorTag 枚举一致
    public static let tags: [String: TagTone] = [
        "urgent": TagTone(fill: Pair(light: "#C96A5E", dark: "#DB8C80"), text: Pair(light: "#A63A2E", dark: "#E89A8E")),
        "inspiration": TagTone(fill: Pair(light: "#D6B04E", dark: "#C9A54F"), text: Pair(light: "#7A5A12", dark: "#DDB565")),
        "daily": TagTone(fill: Pair(light: "#6E8FB3", dark: "#8FA9C6"), text: Pair(light: "#476A8F", dark: "#A5BBD3")),
        "memo": TagTone(fill: Pair(light: "#7FA276", dark: "#9DB894"), text: Pair(light: "#55714F", dark: "#A6C09C")),
        "emotion": TagTone(fill: Pair(light: "#94739F", dark: "#B79BC9"), text: Pair(light: "#7A5A86", dark: "#C4ACD3")),
        "idea": TagTone(fill: Pair(light: "#D08A4E", dark: "#DDA26E"), text: Pair(light: "#94531C", dark: "#E5B288")),
    ]

    /// 键为 EmotionLevel 的 rawValue（-3…3）
    public static let moods: [Int: Pair] = [
        -3: Pair(light: "#7A5A86", dark: "#A98BB5"),
        -2: Pair(light: "#B08FB8", dark: "#C3A8CB"),
        -1: Pair(light: "#9FB0C3", dark: "#A5B5C7"),
        0: Pair(light: "#A9C7C8", dark: "#A3C2C3"),
        1: Pair(light: "#A5C49A", dark: "#9DBB92"),
        2: Pair(light: "#DDC57A", dark: "#DCC47C"),
        3: Pair(light: "#E0A25E", dark: "#E3A768"),
    ]

    public static let subEmotions: [String: Pair] = [
        "sad": Pair(light: "#A393C2", dark: "#BCAED4"),
        "angry": Pair(light: "#C97B70", dark: "#DB9A90"),
        "uncomfortable": Pair(light: "#D59A62", dark: "#E0AF80"),
    ]
}
