// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 「今日一览」卡：记录数 / 待办数 / 情绪状态条，文字 + 图标三段式。
/// 实色卡片（SolidCard）；数字用等宽数字字体，随数据变化走 numericText 过渡。
public struct HomeTodayOverviewCard: View {
    /// 今日记录数（日志 + 灵感）
    public let recordCount: Int
    /// 未完成待办数（全部，不限今日）
    public let openTaskCount: Int
    /// 最近一条情绪的 emoji；无记录时传占位
    public let emotionEmoji: String
    /// 情绪状态文字（如「平静」；无记录时传「还没有记录」）
    public let emotionTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(recordCount: Int, openTaskCount: Int, emotionEmoji: String, emotionTitle: String) {
        self.recordCount = recordCount
        self.openTaskCount = openTaskCount
        self.emotionEmoji = emotionEmoji
        self.emotionTitle = emotionTitle
    }

    public var body: some View {
        SolidCard {
            // 三档，依次取第一个放得下的，标签永远完整显示（不截断成「今日…」「还没…」）：
            // 1. 宽：图标在左、数值/标签在右（macOS 主窗口原样）
            // 2. 紧凑：图标与数值同行、标签在下，列距收紧（iPhone 竖屏常规字号）
            // 3. 纵向：每项独占一行、标签自由换行（辅助功能超大字号兜底）
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.lg) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        if index > 0 { Divider().frame(maxHeight: 36) }
                        wideItem(entry)
                    }
                }
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        if index > 0 { Divider().frame(maxHeight: 44) }
                        compactItem(entry)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        if index > 0 { Divider() }
                        stackedItem(entry)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Entry {
        let icon: String
        let tint: Color
        let value: String
        let label: String
    }

    private var entries: [Entry] {
        [
            Entry(icon: "square.and.pencil", tint: BrandColors.logPurple,
                  value: "\(recordCount)", label: "今日记录"),
            Entry(icon: "checkmark.circle", tint: BrandColors.calendarGreen,
                  value: "\(openTaskCount)", label: "待办"),
            Entry(icon: "face.smiling", tint: BrandColors.emotionPink,
                  value: emotionEmoji, label: emotionTitle),
        ]
    }

    private func wideItem(_ entry: Entry) -> some View {
        HStack(spacing: Spacing.sm) {
            icon(entry)
                .frame(width: 24) // 图标列宽（几何值，对齐三段）
            VStack(alignment: .leading, spacing: 2) { // 2：数值与标签的紧凑节奏
                value(entry)
                label(entry)
                    .lineLimit(1)
                    // 理想宽度即全文宽度：放不下时 ViewThatFits 改选紧凑版，而不是截断
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func compactItem(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.xxs) {
                icon(entry)
                value(entry)
            }
            label(entry)
                .lineLimit(1)
                // 同宽档：放不下时让位给纵向档，而不是截断
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func stackedItem(_ entry: Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            icon(entry)
            value(entry)
            label(entry)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func icon(_ entry: Entry) -> some View {
        Image(systemName: entry.icon)
            .scaledSystemFont(size: 15, weight: .medium, relativeTo: .body)
            .foregroundStyle(entry.tint)
    }

    private func value(_ entry: Entry) -> some View {
        Text(entry.value)
            .font(.title3.bold())
            .monospacedDigit()
            .foregroundStyle(BrandColors.textPrimary)
            .contentTransition(.numericText())
            .animation(Motion.soft(reduceMotion), value: entry.value)
    }

    private func label(_ entry: Entry) -> some View {
        Text(entry.label)
            .font(Typography.caption)
            .foregroundStyle(BrandColors.textSecondary)
    }
}

#Preview {
    HomeTodayOverviewCard(recordCount: 5, openTaskCount: 2,
                          emotionEmoji: "😊", emotionTitle: "平静")
        .padding(Spacing.lg)
        .background(BrandColors.pageBackground)
}

#Preview("iPhone 宽度") {
    HomeTodayOverviewCard(recordCount: 0, openTaskCount: 0,
                          emotionEmoji: "🙂", emotionTitle: "还没有记录")
        .frame(width: 370)
        .padding(Spacing.md)
        .background(BrandColors.pageBackground)
}
