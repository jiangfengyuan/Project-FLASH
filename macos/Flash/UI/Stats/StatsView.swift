// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import Charts
import FlashCore
import FlashDesign

/// 统计页：洞察结论（ReviewInsights 窗口对比）+ 活跃度/KPI + 情绪趋势/子情绪分布
/// （对齐 Android StatsViewModel + EmotionStatsSection）
struct StatsView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Environment(\.flashRepository) private var repository

    @State private var window: ReviewWindow = .week
    @State private var showsCalendar = false
    @State private var showActivityDetails = false
    /// KPI 卡片入场开关（配合逐项 delay 做 stagger）
    @State private var cardsShown = false
    /// 聚合基准日：跨天翻转由 refreshBaseDateAtMidnight 推进（替代原 TimelineView 分钟级刷新）
    @State private var baseDate = Date()
    /// 映射/聚合缓存：仅在数据写代际、时间窗口或基准日变化时重算
    @State private var aggregateCache = ViewComputeCache<StatsKey, StatsValues>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("回顾").flashPageTitle()
                Spacer()
                Picker("回顾视图", selection: $showsCalendar) {
                    Text("趋势").tag(false)
                    Text("日历").tag(true)
                }.pickerStyle(.segmented).frame(width: 180) // 分段控件固有宽度（几何值）
            }.padding(Spacing.lg)
            ZStack {
                trendsContent
                    .opacity(showsCalendar ? 0 : 1)
                    .allowsHitTesting(!showsCalendar)
                    .accessibilityHidden(showsCalendar)
                // 惰性构建：仅切到「日历」分段才挂载 CalendarView，
                // 其三个 @Query 与聚合不再常驻生效
                if showsCalendar {
                    CalendarView()
                }
            }
        }.background(BrandColors.pageBackground)
        .task { await refreshBaseDateAtMidnight() }
    }

    /// 趋势页：时间窗口选择 + 洞察结论 + 活跃度 + 累计 KPI + 情绪趋势/子情绪分布
    private var trendsContent: some View {
        let stats = aggregateCache.value(for: StatsKey(revision: repository?.revision ?? 0,
                                                       window: window,
                                                       day: DateFormatting.dayString(baseDate))) {
            Self.aggregate(logEntities: logEntities, emotionEntities: emotionEntities,
                           window: window, today: baseDate)
        }
        let daily = stats.daily
        let start = daily.first!.date
        let end = daily.last!.date

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Picker("时间范围", selection: $window) {
                    ForEach(ReviewWindow.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(maxWidth: 400) // 窗口选择器最大宽度（几何值）

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(stats.comparison.conclusion)
                        .font(Typography.cardTitle)
                    Text("\(start) — \(end)").font(Typography.caption).foregroundStyle(.secondary)
                    Text(insightDataLine(comparison: stats.comparison,
                                         logs: stats.periodLogCount,
                                         emotions: stats.periodEmotionCount))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20) // 洞察卡内边距：md 与 lg 之间的特调值
                .background(BrandColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))

                activityChart(stats.activity)
                Text("累计概览 · 全部时间").font(Typography.cardTitle)
                // KPI：图标走四模块色（日志紫 / 灵感黄 / 情绪粉 / 日历绿）
                HStack(spacing: Spacing.sm) {
                    kpiCard("累计日志", stats.totalLogs, "note.text", tint: BrandColors.logPurple, index: 0)
                    kpiCard("累计灵感", stats.totalIdeas, "lightbulb", tint: BrandColors.ideaYellow, index: 1)
                    kpiCard("累计情绪", stats.totalEmotions, "face.smiling", tint: BrandColors.emotionPink, index: 2)
                    kpiCard("活跃天数", stats.activeDays, "calendar", tint: BrandColors.calendarGreen, index: 3)
                }

                if stats.hasEmotionData {
                    // 日均情绪趋势
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("情绪趋势 · 日均值").font(Typography.cardTitle)
                        Text("-3 至 +3，0 为中性；无记录日期不计入均值").font(Typography.caption).foregroundStyle(.secondary)
                        Chart {
                            RuleMark(y: .value("中性", 0))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(BrandColors.weakBorder)
                            ForEach(Array(daily.enumerated()), id: \.offset) { _, item in
                                if let average = item.average {
                                    LineMark(
                                        x: .value("日期", item.date),
                                        y: .value("均值", average)
                                    )
                                    .foregroundStyle(BrandColors.accent)
                                    PointMark(
                                        x: .value("日期", item.date),
                                        y: .value("均值", average)
                                    )
                                    .foregroundStyle(BrandColors.accent)
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

                    if !stats.distribution.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("负面情绪构成").font(Typography.cardTitle)
                            Text("伤心 / 生气 / 难受的出现次数，次数见条形末端数值")
                                .font(Typography.caption).foregroundStyle(.secondary)
                            Chart(stats.distribution, id: \.name) { item in
                                BarMark(
                                    x: .value("次数", item.count),
                                    y: .value("类型", item.name)
                                )
                                .foregroundStyle(BrandColors.brandPrimary)
                                .cornerRadius(Radius.hairline)
                                .annotation(position: .trailing) {
                                    Text("\(item.count) 次")
                                        .font(Typography.fine).foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 140) // 图表固有高度（几何值）
                            .animation(Motion.soft(reduceMotion), value: windowDays)
                        }
                    }
                } else {
                    // PRD §34：回顾页空态用品牌化 EmptyStateView（内置 .appear 过渡）
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "再记录一点，未来的你会看到。",
                        message: "先在「情绪」页记录几天吧",
                        iconTint: BrandColors.emotionPink
                    )
                    .frame(minHeight: 180) // 嵌入 ScrollView 内容流，给空态最小高度
                }
            }
            .padding(Spacing.lg)
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

    /// 聚合缓存键：数据写代际（任一表提交即递增）+ 时间窗口 + 基准日。
    /// 不能改用 @Query 实体数组比较：PersistentModel 相等走身份，漏掉就地属性更新。
    private struct StatsKey: Equatable {
        let revision: Int
        let window: ReviewWindow
        let day: String
    }

    /// 一次聚合的全部产物：body 各区块只读不重算
    private struct StatsValues {
        let daily: [(date: String, average: Double?)]
        let activity: [DailyActivity]
        let comparison: ReviewInsights.Comparison
        /// 负面子情绪分布（次数降序，稳定次序便于对照）
        let distribution: [(name: String, count: Int)]
        let totalLogs: Int
        let totalIdeas: Int
        let totalEmotions: Int
        let activeDays: Int
        let hasEmotionData: Bool
        let periodLogCount: Int
        let periodEmotionCount: Int
    }

    /// 实体 → 模型只映射一次，KPI 与图表统计复用同一结果；仅在缓存键变化时执行
    private static func aggregate(logEntities: [LogEntity], emotionEntities: [EmotionEntity],
                                  window: ReviewWindow, today: Date) -> StatsValues {
        let windowDays = window.days(today: today)
        return Perf.measure("StatsAggregate") {
            let logs = logEntities.map { $0.toModel() }
            let emotions = emotionEntities.map { $0.toModel() }
            let daily = EmotionStats.dailyAverages(emotions, days: windowDays, today: today)
            let totalLogs = logs.filter { $0.category == .log }.count
            let totalIdeas = logs.filter { $0.category == .idea }.count
            let activeDays = Set(logs.map(\.recordDate) + emotions.map(\.recordDate)).count
            // 洞察结论：当前窗口 vs 前一等长窗口（Domain/ReviewInsights，含数据量下限）
            let comparison = ReviewInsights.compare(logs: logs, emotions: emotions,
                                                    window: window, today: today)
            let activity = ActivityStats.daily(logs: logs, emotions: emotions,
                                               days: windowDays, today: today)
            let hasEmotionData = EmotionStats.hasEmotionData(emotions, days: windowDays, today: today)
            let distribution = EmotionStats.subEmotionDistribution(emotions,
                                                                   days: windowDays, today: today)
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            let start = daily.first!.date
            let end = daily.last!.date
            let periodLogCount = logs.filter { $0.recordDate >= start && $0.recordDate <= end }.count
            let periodEmotionCount = emotions.filter { $0.recordDate >= start && $0.recordDate <= end }.count
            return StatsValues(daily: daily, activity: activity, comparison: comparison,
                               distribution: distribution, totalLogs: totalLogs,
                               totalIdeas: totalIdeas, totalEmotions: emotions.count,
                               activeDays: activeDays, hasEmotionData: hasEmotionData,
                               periodLogCount: periodLogCount, periodEmotionCount: periodEmotionCount)
        }
    }

    /// 跨天翻转：睡到次日零点推进基准日（缓存键随之变化、触发重聚合）；
    /// .task 在视图消失时自动取消，无需手动管理生命周期
    private func refreshBaseDateAtMidnight() async {
        let calendar = Calendar(identifier: .gregorian)
        while !Task.isCancelled {
            let startOfToday = calendar.startOfDay(for: Date())
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                ?? startOfToday.addingTimeInterval(86_400)
            try? await Task.sleep(for: .seconds(max(0, nextMidnight.timeIntervalSinceNow) + 1))
            guard !Task.isCancelled else { return }
            baseDate = Date()
        }
    }

    /// 动画观测值：窗口天数（与原实现一致，窗口切换驱动图表过渡）
    private var windowDays: Int { window.days(today: baseDate) }

    private func activityChart(_ days: [DailyActivity]) -> some View {
        let maximum = max(1, days.map(\.total).max() ?? 0)
        let active = days.filter { $0.total > 0 }.count
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("记录活跃度").font(Typography.cardTitle)
            Text("每天的日志、灵感与情绪次数 · 不含任务").font(Typography.caption).foregroundStyle(.secondary)
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
            if active == 0 { Text("这段时间还没有记录，空白日期按 0 次显示。").font(Typography.caption) }
            DisclosureGroup("每日明细", isExpanded: $showActivityDetails) {
                ForEach(days) { day in
                    Text("\(day.date)：\(day.records) 条记录 · \(day.emotions) 次情绪")
                        .font(Typography.caption).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20) // 图表卡内边距：md 与 lg 之间的特调值
        .background(BrandColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
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

    private func kpiCard(_ title: String, _ value: Int, _ icon: String,
                         tint: Color, index: Int) -> some View {
        VStack(spacing: 6) { // 6：图标-数字-标题的紧凑节奏（无对应令牌）
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true) // 装饰图标，读屏由数值+标题承载
            Text("\(value)")
                .font(.title2).bold()
                .contentTransition(.opacity) // 数字变化淡变
                .animation(Motion.quick(reduceMotion), value: value)
            Text(title).font(Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .padding(.vertical, Spacing.md)
        .background(BrandColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .stroke(BrandColors.weakBorder, lineWidth: 0.5)
        }
        .flashCardShadow()
        // 入场 stagger：淡入 + 微上移（对齐 AnyTransition.appear 语义）
        .opacity(cardsShown ? 1 : 0)
        .offset(y: cardsShown ? 0 : 6)
        .animation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(index)),
                   value: cardsShown)
    }
}
