// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// Memory 周报页（PRD §22 V1.1 规则聚合版）：周导航 +「You recorded」四计数 +
///「This week felt...」情绪概览 +「Highlights」亮点列表 + 品牌收尾句。
/// 聚合逻辑在 Domain/WeeklyMemory（纯函数），本视图只做查询、缓存与呈现。
struct MemoryView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]
    @Environment(\.flashRepository) private var repository

    /// 周偏移：0 = 本周，-1 = 上一周……（不允许进入未来周）
    @State private var weekOffset = 0
    /// 聚合基准日：跨天翻转由 refreshBaseDateAtMidnight 推进（与 StatsView 同模式）
    @State private var baseDate = Date()
    /// 映射/聚合缓存：仅在数据写代际、周偏移或基准日变化时重算
    @State private var aggregateCache = ViewComputeCache<MemoryKey, WeeklyMemory.Report>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let report = aggregateCache.value(for: MemoryKey(revision: repository?.revision ?? 0,
                                                         weekOffset: weekOffset,
                                                         day: DateFormatting.dayString(baseDate))) {
            let calendar = Calendar(identifier: .gregorian)
            let weekBase = calendar.date(byAdding: .day, value: weekOffset * 7, to: baseDate) ?? baseDate
            return Perf.measure("MemoryAggregate") {
                WeeklyMemory.report(logs: logEntities.map { $0.toModel() },
                                    emotions: emotionEntities.map { $0.toModel() },
                                    tasks: taskEntities.map { $0.toModel() },
                                    baseDate: weekBase)
            }
        }

        VStack(spacing: 0) {
            header(report)
            if report.hasData {
                reportContent(report)
            } else {
                // PRD §34：Memory 空态文案
                EmptyStateView(
                    systemImage: "clock.arrow.circlepath",
                    title: "再记录一点，未来的你会看到。",
                    message: "这一周还没有记录",
                    iconTint: BrandColors.logPurple
                )
            }
        }
        .background(BrandColors.pageBackground)
        .animation(Motion.soft(reduceMotion), value: report)
        .task { await refreshBaseDateAtMidnight() }
    }

    /// 标题 + 周导航（上一周 / 回到本周 / 下一周，下一周不超过当前周）+ 周范围
    private func header(_ report: WeeklyMemory.Report) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("Memory").flashPageTitle()
            Spacer()
            Button {
                Motion.animate(Motion.quick(), reduceMotion: reduceMotion) { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("上一周")
            Button("回到本周") {
                Motion.animate(Motion.quick(), reduceMotion: reduceMotion) { weekOffset = 0 }
            }
            .disabled(weekOffset == 0)
            Button {
                Motion.animate(Motion.quick(), reduceMotion: reduceMotion) { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("下一周")
            .disabled(weekOffset == 0) // 不允许进入未来周
            Text("\(report.weekStart) — \(report.weekEnd)")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(Motion.quick(reduceMotion), value: report.weekStart)
        }
        .padding(Spacing.lg)
    }

    /// 周报内容：四计数卡片 + 情绪概览 + 亮点 + 品牌收尾句
    private func reportContent(_ report: WeeklyMemory.Report) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("You recorded").font(Typography.cardTitle)
                    HStack(spacing: Spacing.sm) {
                        countCard("moments", report.moments, "note.text", tint: BrandColors.logPurple)
                        countCard("ideas", report.ideas, "lightbulb", tint: BrandColors.ideaYellow)
                        countCard("tasks", report.tasks, "checkmark.circle", tint: BrandColors.calendarGreen)
                        countCard("emotions", report.emotions, "face.smiling", tint: BrandColors.emotionPink)
                    }
                }

                if let mood = report.mood {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("This week felt...").font(Typography.cardTitle)
                        HStack(spacing: Spacing.sm) {
                            Text(mood.emoji).scaledSystemFont(size: 28, relativeTo: .title)
                            Text(mood.text).font(Typography.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20) // 情绪卡内边距：md 与 lg 之间的特调值
                    .background(BrandColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .flashCardShadow()
                }

                if !report.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Highlights").font(Typography.cardTitle)
                        ForEach(Array(report.highlights.enumerated()), id: \.offset) { _, title in
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                                Text("•").foregroundStyle(.secondary)
                                Text(title).font(Typography.body)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20) // 亮点卡内边距：md 与 lg 之间的特调值
                    .background(BrandColors.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .flashCardShadow()
                }

                Text("A week worth remembering. ✦")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Spacing.lg)
        }
        .background(BrandColors.pageBackground)
    }

    private func countCard(_ title: String, _ value: Int, _ icon: String, tint: Color) -> some View {
        VStack(spacing: 6) { // 6：图标-数字-标题的紧凑节奏（与 StatsView KPI 卡一致）
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true) // 装饰图标，读屏由数值+标题承载
            Text("\(value)")
                .font(.title2).bold()
                .contentTransition(.opacity)
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
    }

    /// 聚合缓存键：数据写代际 + 周偏移 + 基准日（同 StatsView 键语义）
    private struct MemoryKey: Equatable {
        let revision: Int
        let weekOffset: Int
        let day: String
    }

    /// 跨天翻转：睡到次日零点推进基准日（缓存键随之变化、触发重聚合）；
    /// .task 在视图消失时自动取消
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
}
