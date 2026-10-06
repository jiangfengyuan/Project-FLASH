// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

/// 今日条目：快照为 nil（组不可用 / 无快照 / JSON 损坏）时走引导态视图，
/// 永不留白或报错。
struct FlashTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct FlashTodayProvider: TimelineProvider {
    func placeholder(in _: Context) -> FlashTodayEntry {
        FlashTodayEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (FlashTodayEntry) -> Void) {
        completion(FlashTodayEntry(date: Date(), snapshot: WidgetSnapshotReader.read()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<FlashTodayEntry>) -> Void) {
        let now = Date()
        let entry = FlashTodayEntry(date: now, snapshot: WidgetSnapshotReader.read())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3600))))
    }
}

struct FlashTodayWidget: Widget {
    let kind = "FlashTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlashTodayProvider()) { entry in
            FlashTodayWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "flash://today"))
        }
        .configurationDisplayName("Flash 此刻")
        .description("一览今日记录、待办与主导情绪。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct FlashTodayWidgetEntryView: View {
    let entry: FlashTodayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("✦ Flash")
                .font(.headline)
            Spacer()
            if let snapshot = entry.snapshot {
                Text(snapshot.recordDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer()
            if let snapshot = entry.snapshot {
                HStack(spacing: 8) {
                    if let emoji = snapshot.dominantEmotionEmoji {
                        Text(emoji).font(.title)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(snapshot.todayLogCount) 条记录")
                            .font(.subheadline)
                        Text("\(snapshot.openTaskCount) 项待办")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                placeholderHint
            }
        }
        .padding()
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer()
            if let snapshot = entry.snapshot {
                HStack(spacing: 16) {
                    if let emoji = snapshot.dominantEmotionEmoji {
                        Text(emoji).font(.largeTitle)
                    }
                    statColumn(title: "今日记录", value: snapshot.todayLogCount)
                    statColumn(title: "待办", value: snapshot.openTaskCount)
                    Spacer()
                }
            } else {
                placeholderHint
            }
        }
        .padding()
    }

    private func statColumn(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var placeholderHint: some View {
        Text("打开 Flash 开始记录今天")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
