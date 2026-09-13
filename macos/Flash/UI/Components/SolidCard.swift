// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 实色卡片：表单与高密度列表的默认容器。
/// 浅色用 #FFFFFF 实色表面，深色用品牌弱表面 #3A3D5C，不依赖玻璃模糊；
/// 装饰性 / 焦点场景继续使用 `GlassCard`。
/// 圆角默认 24（常规卡片），焦点卡片 / 底部面板传 `Radius.focus`（32）。
struct SolidCard<Content: View>: View {
    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = Radius.card, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BrandColors.cardSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(BrandColors.weakBorder, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    SolidCard {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("SolidCard")
                .font(.headline)
                .foregroundStyle(BrandColors.textPrimary)
            Text("表单与高密度列表的实色容器。")
                .font(.subheadline)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(Spacing.md)
    }
    .padding(Spacing.lg)
    .background(BrandColors.pageBackground)
}
