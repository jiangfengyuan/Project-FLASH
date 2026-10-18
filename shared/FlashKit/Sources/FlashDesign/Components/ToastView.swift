// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 顶部轻提示（toast）：悬浮层玻璃胶囊（`flashGlassBackground`，macOS 26+ Liquid Glass /
/// macOS 15 regularMaterial + 细边框）+ 悬浮层阴影令牌。
/// 出现/消失过渡内置为 FlashMotion `.pop`（淡入 + 缩放 0.94，锚点顶部），
/// 尊重 Reduce Motion。已实测：SwiftUI 会采用被插入视图 body 根部的 transition，
/// 因此调用方只需用 `Motion.animate`/`withAnimation` 切换 message 即可，
/// 不要再叠加自己的 `.transition`（会与内置过渡复合）。
/// 自动消隐由外部定时把 message 置回 nil（参考 HomeView 用法）。
public struct ToastView: View {
    public let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        Text(message)
            .font(.body.weight(.medium))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 14) // 胶囊横向呼吸：无对应间距令牌（sm 偏紧、md 偏宽）
            .padding(.vertical, Spacing.xs)
            .flashGlassBackground(in: Capsule())
            .flashElevatedShadow()
            .accessibilityLabel(message)
            .transition(.pop(reduceMotion: reduceMotion))
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ToastView(message: "✓ 已保存到日志")
        ToastView(message: "✓ 已保存到灵感")
    }
    .padding(Spacing.lg)
    .frame(width: 360, height: 160)
}
