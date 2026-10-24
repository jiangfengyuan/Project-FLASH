// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 筛选 Chip：默认选中态用深墨 #2D3436 实心 + 白字（跨端统一裁决），未选中用弱表面 + 弱边界。
/// 传入 `accent`/`accentText`（模块色，如灵感黄）时，选中态改用模块色淡底 + 描边 + 可读文字变体。
/// 状态同时由颜色与文案加粗表达（品牌标准 §03 可访问性：不只靠颜色区分）；
/// 字号用 Typography.secondary（.callout，随系统字体放大），垂直内距用 Spacing.xs 令牌。
/// 未选中时 hover 描边微亮（Motion.quick）；选中切换走 Motion.soft
///（220ms，处于选中态 160–240ms 令牌区间内），尊重减少动态。
public struct FilterChipView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let title: String
    public let isSelected: Bool
    /// 模块色选中态（nil = 统一深墨实心）；仅作点缀，状态仍由加粗与填充表达
    public var accent: Color? = nil
    /// 模块色选中态的文字用可读变体（配 accent 使用）
    public var accentText: Color? = nil
    public let action: () -> Void

    @State private var hovering = false

    private var usesAccent: Bool { isSelected && accent != nil }

    public init(title: String, isSelected: Bool, accent: Color? = nil, accentText: Color? = nil,
                action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.accent = accent
        self.accentText = accentText
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.secondary.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected
                                 ? (accentText ?? BrandColors.chipSelectedForeground)
                                 : BrandColors.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    Capsule()
                        .fill(isSelected
                              ? (accent?.opacity(0.22) ?? BrandColors.chipSelectedBackground)
                              : BrandColors.weakSurface)
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(hovering ? BrandColors.textSecondary.opacity(0.6)
                                                   : BrandColors.weakBorder,
                                          lineWidth: 0.5)
                    } else if let accent {
                        Capsule()
                            .strokeBorder(accent, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick(reduceMotion), value: hovering)
        .animation(Motion.soft(reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack(spacing: Spacing.xs) {
        FilterChipView(title: "全部", isSelected: true) {}
        FilterChipView(title: "灵感", isSelected: true,
                       accent: BrandColors.ideaYellow, accentText: BrandColors.ideaYellowText) {}
        FilterChipView(title: "日常", isSelected: false) {}
    }
    .padding(Spacing.lg)
    .background(BrandColors.pageBackground)
}
