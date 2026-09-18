// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 筛选 Chip：选中态用深墨 #2D3436 实心 + 白字（跨端统一裁决），未选中用弱表面 + 弱边界。
/// 状态同时由颜色与文案加粗表达（品牌标准 §03 可访问性：不只靠颜色区分）；
/// 字号用 .callout（13pt 等效，随系统字体放大），垂直内距用 Spacing.xs（8）令牌。
/// 选中切换走 Motion.soft（220ms，处于选中态 160–240ms 令牌区间内），尊重减少动态。
struct FilterChipView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? BrandColors.chipSelectedForeground : BrandColors.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background {
                    Capsule()
                        .fill(isSelected ? BrandColors.chipSelectedBackground : BrandColors.weakSurface)
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(BrandColors.weakBorder, lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(Motion.soft(reduceMotion), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack(spacing: Spacing.xs) {
        FilterChipView(title: "全部", isSelected: true) {}
        FilterChipView(title: "灵感", isSelected: false) {}
        FilterChipView(title: "日常", isSelected: false) {}
    }
    .padding(Spacing.lg)
    .background(BrandColors.pageBackground)
}
