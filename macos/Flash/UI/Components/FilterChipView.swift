// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 筛选 Chip：选中态用品牌主操作蓝紫，未选中用弱表面 + 弱边界。
/// 状态同时由颜色与文案加粗表达（品牌标准 §03 可访问性：不只靠颜色区分）；
/// 选中切换走 Motion.soft（220ms，处于选中态 160–240ms 令牌区间内），尊重减少动态。
/// 命名带 View 后缀：ExploreView 内已有 file 级私有 `FilterChip`，避免模块内重名。
struct FilterChipView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : BrandColors.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(isSelected ? BrandColors.brandPrimary : BrandColors.weakSurface)
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
