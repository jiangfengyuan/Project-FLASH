// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// Flash 设计令牌 —— 间距 / 圆角 / 布局 / 字体 / 阴影（品牌标准 §05/§30/§31，全端统一数值）
///
/// 色值令牌见 `BrandColors.swift`；动效令牌见 `FlashMotion.swift`
///（选中态 160–240ms 淡入 + 轻位移，对应 Motion.durationFast…durationBase，
///  全部尊重系统「减少动态效果」）。
public enum Spacing {
    /// 极紧凑：徽章内距、格子内堆叠
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

/// 圆角梯度（品牌标准 §31 Shape System：Small 12–16 / Card 20–24 / Hero 28–32）
public enum Radius {
    /// 图表条形末端等微小圆角
    public static let hairline: CGFloat = 4
    /// 小控件（侧栏选中胶囊）
    public static let control: CGFloat = 6
    #if os(iOS)
    // iOS 暖调手作主题：触屏卡片更圆润，贴近手作纸卡的柔和边角
    public static let field: CGFloat = 12
    public static let row: CGFloat = 16
    public static let panel: CGFloat = 14
    public static let cardSmall: CGFloat = 20
    #else
    /// 输入框、徽章底、日历格
    public static let field: CGFloat = 8
    /// 列表行卡（日志卡、任务行、情绪行）
    public static let row: CGFloat = 10
    /// 浮层 / 小面板（菜单栏伴侣、popover）
    public static let panel: CGFloat = 12
    /// 小组件卡（本周趋势）
    public static let cardSmall: CGFloat = 16
    #endif
    /// 点缀玻璃卡（GlassCard 默认）
    public static let glass: CGFloat = 20
    /// 常规卡片
    public static let card: CGFloat = 24
    /// 焦点卡片 / 底部面板
    public static let focus: CGFloat = 32
}

public enum Metrics {
    /// 图标按钮最小触控尺寸 44×44
    public static let minTouchTarget: CGFloat = 44
    /// 桌面端阅读内容最大宽度
    public static let readingMaxWidth: CGFloat = 720
    /// 桌面端工具页内容最大宽度
    public static let toolMaxWidth: CGFloat = 1200
}

// MARK: - 字体（品牌标准 §30 Typography）

/// 语义化字号令牌：全部用 SwiftUI 相对 TextStyle，随系统字体档位缩放。
/// 必须固定基准尺寸的展示字形（hero emoji、图标、PIN）走 `View.scaledSystemFont`（@ScaledMetric）。
public enum Typography {
    #if os(iOS)
    // iOS 暖调手作主题：展示性标题用随包的霞鹜文楷（OFL，只含 GB2312 常用字，
    // 缺字由系统回退到苹方），正文与控件仍是系统字体（品牌标准 §04 / §08）。
    // 扩展（小组件、分享）未打包字体，Font.custom 自动回退系统字体。

    /// 随包手写感展示字体的 PostScript 名（app/ios/Flash/Fonts/LXGWWenKai-Medium.ttf）
    public static let displayFontName = "LXGWWenKai-Medium"

    /// 页面大标题（此刻问候 / 回顾 / 设置）
    public static let pageTitle = Font.custom(displayFontName, size: 34, relativeTo: .largeTitle)
    /// 欢迎页标题
    public static let heroTitle = Font.custom(displayFontName, size: 28, relativeTo: .title)
    /// 页面/面板区块标题（记录页标题、任务编辑器、LAN 面板）
    public static let sectionTitle = Font.custom(displayFontName, size: 22, relativeTo: .title2)
    /// 统计数值：New York 衬线数字，带一点印刷的温度
    public static let statValue = Font.system(.title3, design: .serif).bold()
    /// 大号统计数值（回顾 / 记忆页的主数字）
    public static let statValueLarge = Font.system(.title2, design: .serif).bold()
    /// 卡片内区块标题（本周趋势、近期记录……）：手写感展示字体
    public static let blockTitle = Font.custom(displayFontName, size: 18, relativeTo: .headline)

    /// 短标题（≤ 12 字，如「最近闪念」）用手写感展示字体，按给定文本样式缩放
    public static func display(_ style: Font.TextStyle) -> Font {
        Font.custom(displayFontName, size: displaySize(style), relativeTo: style)
    }

    private static func displaySize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
    #else
    /// 页面大标题（此刻问候 / 回顾 / 设置）
    public static let pageTitle = Font.largeTitle.bold()
    /// 欢迎页标题
    public static let heroTitle = Font.title.bold()
    /// 页面/面板区块标题（记录页标题、任务编辑器、LAN 面板）
    public static let sectionTitle = Font.title2.bold()
    /// 统计数值
    public static let statValue = Font.title3.bold()
    /// 大号统计数值（回顾 / 记忆页的主数字）
    public static let statValueLarge = Font.title2.bold()
    /// 卡片内区块标题（本周趋势、近期记录……）
    public static let blockTitle = Font.headline

    /// 短标题：macOS 沿用系统字体加粗
    public static func display(_ style: Font.TextStyle) -> Font {
        Font.system(style).weight(.semibold)
    }
    #endif
    /// 卡片 / 分组标题
    public static let cardTitle = Font.headline
    /// 正文
    public static let body = Font.body
    /// 次要说明（副标题、分组标题行）
    public static let secondary = Font.callout
    /// 辅助信息（时间戳、注脚、统计摘要）
    public static let caption = Font.caption
    /// 图表注记等最小信息层
    public static let fine = Font.caption2
}

extension View {
    /// 页面大标题（此刻问候 / 回顾 / 设置）
    public func flashPageTitle() -> some View {
        font(Typography.pageTitle).foregroundStyle(BrandColors.textPrimary)
    }

    /// 页面 / 面板区块标题
    public func flashSectionTitle() -> some View {
        font(Typography.sectionTitle).foregroundStyle(BrandColors.textPrimary)
    }

    /// 固定基准尺寸、但随系统字体档位缩放的字形（图标、hero emoji、配对 PIN 等展示元素）
    public func scaledSystemFont(size: CGFloat, weight: Font.Weight = .regular,
                          design: Font.Design = .default,
                          relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(ScaledSystemFontModifier(baseSize: size, weight: weight,
                                          design: design, textStyle: textStyle))
    }
}

private struct ScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(baseSize: CGFloat, weight: Font.Weight, design: Font.Design, textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: baseSize, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

// MARK: - 阴影

/// 阴影令牌：card（柔和，内容卡片）/ elevated（悬浮层：Toast、浮层）。
/// 深色外观下不透明度走高（深底上阴影需要更强才能被感知）。
public enum Shadow {
    public struct Spec: Sendable {
        public let radius: CGFloat
        public let y: CGFloat
        /// 浅色外观不透明度
        public let opacity: Double
        /// 深色外观不透明度
        public let darkOpacity: Double

        public init(radius: CGFloat, y: CGFloat, opacity: Double, darkOpacity: Double) {
            self.radius = radius
            self.y = y
            self.opacity = opacity
            self.darkOpacity = darkOpacity
        }
    }

    #if os(iOS)
    /// 柔和卡片阴影（暖褐色、更散，像纸卡轻放在桌面）
    public static let card = Spec(radius: 12, y: 4, opacity: 0.07, darkOpacity: 0.28)
    /// 悬浮层阴影（Toast、浮层面板）
    public static let elevated = Spec(radius: 16, y: 8, opacity: 0.12, darkOpacity: 0.34)
    #else
    /// 柔和卡片阴影
    public static let card = Spec(radius: 8, y: 2, opacity: 0.06, darkOpacity: 0.25)
    /// 悬浮层阴影（Toast、浮层面板）
    public static let elevated = Spec(radius: 12, y: 6, opacity: 0.12, darkOpacity: 0.32)
    #endif
}

extension View {
    /// 柔和卡片阴影（Shadow.card）
    public func flashCardShadow() -> some View {
        modifier(FlashShadowModifier(spec: Shadow.card))
    }

    /// 悬浮层阴影（Shadow.elevated）
    public func flashElevatedShadow() -> some View {
        modifier(FlashShadowModifier(spec: Shadow.elevated))
    }
}

private struct FlashShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let spec: Shadow.Spec

    func body(content: Content) -> some View {
        content.shadow(color: BrandColors.shadowTint.opacity(colorScheme == .dark ? spec.darkOpacity : spec.opacity),
                       radius: spec.radius, y: spec.y)
    }
}
