// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 「今日一览」卡：记录数 / 待办数 / 情绪状态条，文字 + 图标三段式。
/// 实色卡片（SolidCard）；数字用等宽数字字体，随数据变化走 numericText 过渡。
struct HomeTodayOverviewCard: View {
    /// 今日记录数（日志 + 灵感）
    let recordCount: Int
    /// 未完成待办数（全部，不限今日）
    let openTaskCount: Int
    /// 最近一条情绪的 emoji；无记录时传占位
    let emotionEmoji: String
    /// 情绪状态文字（如「平静」；无记录时传「还没有记录」）
    let emotionTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SolidCard {
            HStack(spacing: Spacing.lg) {
                item(icon: "square.and.pencil", tint: BrandColors.logPurple,
                     value: "\(recordCount)", label: "今日记录")
                Divider().frame(maxHeight: 36)
                item(icon: "checkmark.circle", tint: BrandColors.calendarGreen,
                     value: "\(openTaskCount)", label: "待办")
                Divider().frame(maxHeight: 36)
                item(icon: "face.smiling", tint: BrandColors.emotionPink,
                     value: emotionEmoji, label: emotionTitle)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func item(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .foregroundStyle(BrandColors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(Motion.soft(reduceMotion), value: value)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeTodayOverviewCard(recordCount: 5, openTaskCount: 2,
                          emotionEmoji: "😊", emotionTitle: "平静")
        .padding(Spacing.lg)
        .background(BrandColors.pageBackground)
}
