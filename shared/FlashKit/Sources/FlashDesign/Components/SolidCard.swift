// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 实色卡片：表单与高密度列表的默认容器。
/// 浅色用 #FFFFFF 实色表面，深色用品牌弱表面 #3A3D5C，不依赖玻璃模糊；
/// 装饰性 / 焦点场景继续使用 `GlassCard`。
/// 圆角默认 24（常规卡片），焦点卡片 / 底部面板传 `Radius.focus`（32）。
public struct SolidCard<Content: View>: View {
    public let cornerRadius: CGFloat
    /// 主卡片的撕开毛边（iOS）；决定形状的种子同时让每张卡的起伏不同
    public let seed: String
    public let frayed: Bool
    private let content: Content

    public init(cornerRadius: CGFloat = Radius.card, seed: String = "card", frayed: Bool = false,
                @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.seed = seed
        self.frayed = frayed
        self.content = content()
    }

    public var body: some View {
        #if os(iOS)
        let shape = PaperCardShape(seed: seed, cornerRadius: cornerRadius, frayed: frayed)
        content
            .background { shape.fill(BrandColors.cardSurface) }
            .overlay { shape.stroke(BrandColors.weakBorder, lineWidth: 0.75) }
            .clipShape(shape)
            // 长而弥散的暖影：纸张微微浮在桌面上
            .flashCardShadow()
        #else
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
        #endif
    }
}

#Preview {
    SolidCard {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("SolidCard")
                .font(Typography.cardTitle)
                .foregroundStyle(BrandColors.textPrimary)
            Text("表单与高密度列表的实色容器。")
                .font(Typography.secondary)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(Spacing.card)
    }
    .padding(Spacing.lg)
    .flashPageBackground()
}
