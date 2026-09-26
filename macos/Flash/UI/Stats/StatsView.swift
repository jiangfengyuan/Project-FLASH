// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import Charts

/// 统计页：洞察结论（ReviewInsights 窗口对比）+ 活跃度/KPI + 情绪趋势/子情绪分布
/// （对齐 Android StatsViewModel + EmotionStatsSection）
struct StatsView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var window: ReviewWindow = .week
    @State private var showsCalendar = false
    @State private var showActivityDetails = false
    /// KPI 卡片入场开关（配合逐项 delay 做 stagger）
    @State private var cardsShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("回顾").font(.largeTitle.bold())
                Spacer()
                Picker("回顾视图", selection: $showsCalendar) {
                    Text("趋势").tag(false)
                    Text("日历").tag(true)
                }.pickerStyle(.segmented).frame(width: 180)
            }.padding(24)
            ZStack {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = context.date
            let windowDays = window.days(today: today)
            // 实体 → 模型只映射一次，KPI 与图表统计复用同一结果
            let logs = logEntities.map { $0.toModel() }
            let emotions = emotionEntities.map { $0.toModel() }
            let daily = EmotionStats.dailyAverages(emotions, days: windowDays, today: today)
            let start = daily.first!.date
            let end = daily.last!.date
            let totalLogs = logs.filter { $0.category == .log }.count
            let totalIdeas = logs.filter { $0.category == .idea }.count
            let activeDays = Set(logs.map(\.recordDate) + emotions.map(\.recordDate)).count

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("时间范围", selection: $window) {
                        ForEach(ReviewWindow.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).frame(maxWidth: 400)

                    let periodLogs = logs.filter { $0.recordDate >= start && $0.recordDate <= end }
                    let periodEmotions = emotions.filter { $0.recordDate >= start && $0.recordDate <= end }
                    // 洞察结论：当前窗口 vs 前一等长窗口（Domain/ReviewInsights，含数据量下限）
                    let comparison = ReviewInsights.compare(logs: logs, emotions: emotions,
                                                            window: window, today: today)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(comparison.conclusion)
                            .font(.headline)
                        Text("\(start) — \(end)").font(.caption).foregroundStyle(.secondary)
                        Text(insightDataLine(comparison: comparison,
                                             logs: periodLogs.count,
                                             emotions: periodEmotions.count))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20).background(BrandColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                    activityChart(ActivityStats.daily(logs: logs, emotions: emotions, days: windowDays, today: today))
                    Text("累计概览 · 全部时间").font(.headline)
                    // KPI
                    HStack(spacing: 12) {
                        kpiCard("累计日志", totalLogs, "note.text", index: 0)
                        kpiCard("累计灵感", totalIdeas, "lightbulb", index: 1)
                        kpiCard("累计情绪", emotions.count, "face.smiling", index: 2)
                        kpiCard("活跃天数", activeDays, "calendar", index: 3)
                    }

                    if EmotionStats.hasEmotionData(emotions, days: windowDays, today: today) {
                        // 日均情绪趋势
                        VStack(alignment: .leading, spacing: 8) {
                            Text("情绪趋势 · 日均值").font(.headline)
                            Text("-3 至 +3，0 为中性；无记录日期不计入均值").font(.caption).foregroundStyle(.secondary)
                            Chart {
                                RuleMark(y: .value("中性", 0))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundStyle(Color(nsColor: .separatorColor))
                                ForEach(Array(daily.enumerated()), id: \.offset) { _, item in
                                    if let average = item.average {
                                        LineMark(
                                            x: .value("日期", item.date),
                                            y: .value("均值", average)
                                        )
                                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                                        PointMark(
                                            x: .value("日期", item.date),
                                            y: .value("均值", average)
                                        )
                                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                                    }
                                }
                            }
                            .chartYScale(domain: -3...3)
                            .chartYAxis {
                                AxisMarks(values: [-3, -2, -1, 0, 1, 2, 3])
                            }
                            .frame(height: 220)
                            .animation(Motion.soft(reduceMotion), value: windowDays)
                        }

                        // 负面子情绪分布（次数降序，稳定次序便于对照）
                        let distribution = EmotionStats.subEmotionDistribution(emotions,
                                                                               days: windowDays, today: today)
                            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
                        if !distribution.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("负面情绪构成").font(.headline)
                                Text("伤心 / 生气 / 难受的出现次数，次数见条形末端数值")
                                    .font(.caption).foregroundStyle(.secondary)
                                Chart(distribution, id: \.name) { item in
                                    BarMark(
                                        x: .value("次数", item.count),
                                        y: .value("类型", item.name)
                                    )
                                    .foregroundStyle(BrandColors.brandPrimary)
                                    .cornerRadius(4)
                                    .annotation(position: .trailing) {
                                        Text("\(item.count) 次")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(height: 140)
                                .animation(Motion.soft(reduceMotion), value: windowDays)
                            }
                        }
                    } else {
                        ContentUnavailableView("暂无情绪数据",
                                               systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("先在「情绪」页记录几天吧"))
                    }
                }
                .padding(24)
            }
            .background(BrandColors.pageBackground)
            .onAppear {
                if reduceMotion {
                    cardsShown = true
                } else {
                    withAnimation(Motion.softOut()) { cardsShown = true }
                }
            }
        }
        .opacity(showsCalendar ? 0 : 1)
        .allowsHitTesting(!showsCalendar)
        .accessibilityHidden(showsCalendar)
        CalendarView()
            .opacity(showsCalendar ? 1 : 0)
            .allowsHitTesting(showsCalendar)
            .accessibilityHidden(!showsCalendar)
            }
        }.background(BrandColors.pageBackground)
    }

    private func activityChart(_ days: [DailyActivity]) -> some View {
        let maximum = max(1, days.map(\.total).max() ?? 0)
        let active = days.filter { $0.total > 0 }.count
        return VStack(alignment: .leading, spacing: 12) {
            Text("记录活跃度").font(.headline)
            Text("每天的日志、灵感与情绪次数 · 不含任务").font(.caption).foregroundStyle(.secondary)
            Text("\(active) 个活跃日 · 共 \(days.reduce(0) { $0 + $1.total }) 次")
            Chart(days) { day in
                BarMark(x: .value("日期", day.date), y: .value("次数", day.total))
                    .foregroundStyle(BrandColors.brandPrimary)
                    .accessibilityLabel(day.date)
                    .accessibilityValue("\(day.records) 条记录，\(day.emotions) 次情绪")
            }
            .chartYScale(domain: 0...maximum)
            .chartYAxis { AxisMarks(values: [0, maximum]) }
            .frame(height: 160)
            if active == 0 { Text("这段时间还没有记录，空白日期按 0 次显示。").font(.caption) }
            DisclosureGroup("每日明细", isExpanded: $showActivityDetails) {
                ForEach(days) { day in
                    Text("\(day.date)：\(day.records) 条记录 · \(day.emotions) 次情绪")
                        .font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20).background(BrandColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    /// 洞察卡数据行：记录数 + 情绪均值（有情绪记录时）
    private func insightDataLine(comparison: ReviewInsights.Comparison,
                                 logs: Int, emotions: Int) -> String {
        var line = "\(logs) 条记录 · \(emotions) 次情绪"
        if let average = comparison.currentEmotionAverage {
            line += " · 情绪均值 \(formatAverage(average))"
        }
        return line
    }

    /// 均值已由领域层保留两位小数；整数档只显示一位（2 而非 2.00）
    private func formatAverage(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.1f", value) : String(format: "%.2f", value)
    }

    private func kpiCard(_ title: String, _ value: Int, _ icon: String, index: Int) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
                .accessibilityHidden(true) // 装饰图标，读屏由数值+标题承载
            Text("\(value)")
                .font(.title2).bold()
                .contentTransition(.opacity) // 数字变化淡变
                .animation(Motion.quick(reduceMotion), value: value)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        // 入场 stagger：淡入 + 微上移（对齐 AnyTransition.appear 语义）
        .opacity(cardsShown ? 1 : 0)
        .offset(y: cardsShown ? 0 : 6)
        .animation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(index)),
                   value: cardsShown)
    }
}
