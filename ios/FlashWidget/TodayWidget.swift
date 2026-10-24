// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit
import FlashCore
import FlashDesign

// MARK: - 时间线

struct FlashTodayEntry: TimelineEntry {
    let date: Date
    /// nil = 组不可用 / 尚无快照 / JSON 损坏 → 引导态
    let snapshot: WidgetSnapshot?

    /// 跨日后快照仍是昨天的：计数按 0 展示（未读灵感与日期无关）
    var isCurrent: Bool { snapshot?.isCurrent(today: DateFormatting.dayString(date)) ?? false }
    var logCount: Int { isCurrent ? snapshot?.todayLogCount ?? 0 : 0 }
    var openTaskCount: Int { isCurrent ? snapshot?.openTaskCount ?? 0 : 0 }
    var emotionEmoji: String? { isCurrent ? snapshot?.dominantEmotionEmoji : nil }
    var unreadIdeaCount: Int { snapshot?.unreadIdeaCount ?? 0 }
}

struct FlashTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlashTodayEntry {
        FlashTodayEntry(date: Date(), snapshot: WidgetSnapshot(
            recordDate: DateFormatting.today(), todayLogCount: 3, openTaskCount: 1,
            dominantEmotionEmoji: "🙂", generatedAt: DateFormatting.isoNow(), unreadIdeaCount: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (FlashTodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context)
                   : FlashTodayEntry(date: Date(), snapshot: WidgetSnapshotReader.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlashTodayEntry>) -> Void) {
        let now = Date()
        let entry = FlashTodayEntry(date: now, snapshot: WidgetSnapshotReader.read())
        // App 写库后主动 reload；兜底在次日 0 点刷新（跨日计数归零）
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - 主屏「Flash 此刻」

struct FlashTodayWidget: Widget {
    let kind = "FlashTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlashTodayProvider()) { entry in
            FlashTodayView(entry: entry)
                .containerBackground(for: .widget) { BrandColors.pageBackground }
                .widgetURL(URL(string: "flash://today"))
        }
        .configurationDisplayName("Flash 此刻")
        .description("一览今日记录、待办与情绪，一键记下新念头。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FlashTodayView: View {
    let entry: FlashTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xxs) {
            Text("✦ Flash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColors.brandPrimary)
                .widgetAccentable()
            Spacer(minLength: 0)
            if let emoji = entry.emotionEmoji {
                Text(emoji).font(.title3)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            header
            Spacer(minLength: 0)
            if entry.snapshot == nil {
                Text("打开 Flash 开始记录今天")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.logCount)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text("今日记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(secondaryLine)
                    .font(.caption2)
                    .foregroundStyle(entry.unreadIdeaCount >= IdeaReminder.threshold
                                     ? BrandColors.ideaYellowText : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var secondaryLine: String {
        if entry.unreadIdeaCount >= IdeaReminder.threshold { return "\(entry.unreadIdeaCount) 个想法待梳理" }
        return "\(entry.openTaskCount) 项待办"
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                header
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    stat(entry.logCount, "今日记录")
                    stat(entry.openTaskCount, "待办")
                    if entry.unreadIdeaCount > 0 {
                        stat(entry.unreadIdeaCount, "待梳理")
                    }
                }
            }
            VStack(spacing: Spacing.xs) {
                captureLink("灵感", systemImage: "lightbulb", category: .idea, tint: BrandColors.ideaYellow)
                captureLink("日志", systemImage: "square.and.pencil", category: .log, tint: BrandColors.logPurple)
            }
            .frame(width: 104) // 记录按钮列宽（几何值）
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .widgetAccentable()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// 中号小组件内的直达按钮：打开 App 并弹出对应类型的快速记录面板
    private func captureLink(_ title: String, systemImage: String, category: FlashCore.Category,
                             tint: Color) -> some View {
        Link(destination: URL(string: "flash://capture?category=\(category.rawValue)")!) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: Radius.panel))
                .foregroundStyle(BrandColors.textPrimary)
        }
    }
}

// MARK: - 锁屏

struct FlashLockScreenWidget: Widget {
    let kind = "FlashLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlashTodayProvider()) { entry in
            FlashLockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "flash://today"))
        }
        .configurationDisplayName("Flash 锁屏")
        .description("在锁屏上看到今天记了几条、还有几个想法待梳理。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct FlashLockScreenView: View {
    let entry: FlashTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.logCount)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .widgetAccentable()
                    Text("记录").font(.caption2)
                }
            }
            .accessibilityLabel("今日 \(entry.logCount) 条记录")
        case .accessoryInline:
            Text("✦ 今日 \(entry.logCount) 条记录 · \(entry.openTaskCount) 项待办")
        default:
            VStack(alignment: .leading, spacing: 2) { // 2：锁屏行距（几何值）
                Text("✦ Flash")
                    .font(.headline)
                    .widgetAccentable()
                Text("今日 \(entry.logCount) 条 · 待办 \(entry.openTaskCount)")
                    .font(.caption)
                if entry.unreadIdeaCount > 0 {
                    Text("\(entry.unreadIdeaCount) 个想法待梳理")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
