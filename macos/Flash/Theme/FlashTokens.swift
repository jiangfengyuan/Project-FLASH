// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics

/// Flash 设计令牌 —— 间距 / 圆角 / 布局（品牌标准 §05，全端统一数值）
///
/// 色值令牌见 `BrandColors.swift`；动效令牌见 `FlashMotion.swift`
///（选中态 160–240ms 淡入 + 轻位移，对应 Motion.durationFast…durationBase，
///  全部尊重系统「减少动态效果」）。
enum Spacing {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    /// 常规卡片
    static let card: CGFloat = 24
    /// 焦点卡片 / 底部面板
    static let focus: CGFloat = 32
}

enum Metrics {
    /// 图标按钮最小触控尺寸 44×44
    static let minTouchTarget: CGFloat = 44
    /// 桌面端阅读内容最大宽度
    static let readingMaxWidth: CGFloat = 720
    /// 桌面端工具页内容最大宽度
    static let toolMaxWidth: CGFloat = 1200
}
