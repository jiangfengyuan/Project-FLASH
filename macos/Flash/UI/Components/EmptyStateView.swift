// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 空状态：图标 + 标题 + 说明 + 可选主操作。
/// 入场用 Motion.appear（淡入 + 微上移），尊重系统「减少动态效果」。
/// 文案约定（品牌标准 §06）：说「今天还没有记录」，不说「数据为空」。
struct EmptyStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let systemImage: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(BrandColors.textSecondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(BrandColors.textPrimary)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(BrandColors.brandPrimary)
                    .controlSize(.large)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
        .transition(.appear(reduceMotion: reduceMotion))
    }
}

#Preview {
    EmptyStateView(
        systemImage: "tray",
        title: "今天还没有记录",
        message: "记下此刻的想法，它会留在这里等你回看。",
        actionTitle: "新建记录"
    ) {}
    .background(BrandColors.pageBackground)
}
