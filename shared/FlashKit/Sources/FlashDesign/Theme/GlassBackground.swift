// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 悬浮层玻璃背景（视觉原则：80% Clean / 20% Glass，**玻璃只用于悬浮层**——
/// Toast、popover 浮层、菜单栏伴侣面板；内容区卡片保持 Clean，SolidCard/GlassCard
/// 现有分工不动，不要用本封装扩大玻璃面积）。
///
/// 双轨：macOS 26+ / iOS 26+ 用 Liquid Glass `.glassEffect`；macOS 15 / iOS 18–25 回退 `.regularMaterial` + 细边框。
/// 每个悬浮层只承载一个玻璃元素，无需 GlassEffectContainer。
extension View {
    /// 在指定形状上应用悬浮层玻璃背景
    @ViewBuilder
    public func flashGlassBackground<S: InsettableShape>(in shape: S) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        Text("Toast 胶囊")
            .font(Typography.body)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .flashGlassBackground(in: Capsule())
        Text("浮层面板")
            .font(Typography.body)
            .padding(Spacing.lg)
            .flashGlassBackground(in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
    }
    .padding(Spacing.xl)
}
