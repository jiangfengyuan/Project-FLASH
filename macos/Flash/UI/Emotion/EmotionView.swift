// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

/// 情绪页：七级情绪记录（对齐 Android EmotionViewModel）。
/// 主视觉为大 emoji：随等级 .pop 切换，名称色彩沿七级调色板连续插值（§33 Motion）。
/// 区块结构：情绪选择卡片 → 本周趋势 → 近期记录，入场按 50ms 级联错开。
struct EmotionView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sliderValue: Double = 5 // 1...7 → veryUnhappy...slightlyHappy 默认
    @State private var selectedSubEmotion: SubEmotion? = nil
    @State private var note = ""
    @State private var errorMessage: String? = nil

    /// 入场标记：主卡片 / 本周趋势 / 近期记录依次出现
    @State private var heroAppeared = false
    @State private var weekAppeared = false
    @State private var historyAppeared = false

    private var selectedLevel: EmotionLevel {
        EmotionLevel.allCases[Int(sliderValue) - 1]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if heroAppeared {
                    heroCard
                        .transition(.appear(reduceMotion: reduceMotion))
                }
                if weekAppeared {
                    EmotionWeekView()
                        .transition(.appear(reduceMotion: reduceMotion))
                }
                if historyAppeared {
                    EmotionHistoryView()
                        .transition(.appear(reduceMotion: reduceMotion))
                }
            }
            .padding(24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: playEntranceAnimation)
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 情绪选择卡片

    private var heroCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 20) {
                Text("现在感觉怎么样？")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 主视觉：emoji 随等级切换 .pop 过渡，名称色彩沿七级调色板连续插值
                VStack(spacing: 12) {
                    Text(selectedLevel.emoji)
                        .font(.system(size: 64))
                        .id(selectedLevel)
                        .transition(.pop(reduceMotion: reduceMotion))
                        .accessibilityHidden(true)

                    Text(selectedLevel.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(EmotionPalette.color(for: sliderValue))
                        .id(selectedLevel)
                        .transition(.pop(reduceMotion: reduceMotion))
                }
                .animation(Motion.spring(reduceMotion), value: sliderValue)

                Slider(value: $sliderValue, in: 1...7, step: 1) {
                    Text("情绪等级")
                } minimumValueLabel: {
                    Text("😡")
                } maximumValueLabel: {
                    Text("😍")
                }
                .frame(maxWidth: 420)
                .onChange(of: sliderValue) {
                    if !selectedLevel.isNegative { selectedSubEmotion = nil }
                }
                .accessibilityValue(selectedLevel.displayName)

                // 子情绪（仅负面）
                if selectedLevel.isNegative {
                    HStack(spacing: 10) {
                        ForEach(SubEmotion.allCases, id: \.self) { sub in
                            subEmotionChip(sub)
                        }
                    }
                    .animation(Motion.quick(reduceMotion), value: selectedSubEmotion)
                    .transition(.pop(reduceMotion: reduceMotion))
                }

                HStack(spacing: 10) {
                    TextField("想说点什么？（可选）", text: $note)
                        .textFieldStyle(.roundedBorder)
                    Button("记录情绪") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .frame(maxWidth: 420)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .animation(Motion.soft(reduceMotion), value: selectedLevel)
    }

    private func subEmotionChip(_ sub: SubEmotion) -> some View {
        let isOn = selectedSubEmotion == sub
        return Button {
            selectedSubEmotion = isOn ? nil : sub
        } label: {
            Text(sub.displayName)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isOn ? sub.color.opacity(0.3)
                                 : Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? sub.color
                                          : Color(nsColor: .separatorColor),
                                     lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 入场 / 保存

    /// 三个区块按 50ms 级联入场（Motion.staggerDelay）
    private func playEntranceAnimation() {
        guard !heroAppeared else { return }
        withAnimation(Motion.softOut(reduceMotion)) { heroAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(1))) {
            weekAppeared = true
        }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(2))) {
            historyAppeared = true
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func save() {
        let level = selectedLevel
        let sub = level.isNegative ? selectedSubEmotion : nil
        let noteValue = note.isEmpty ? nil : note
        // 包一层动画，让下方历史列表对新增记录做柔和的插入过渡
        Motion.animate(Motion.soft(reduceMotion), reduceMotion: reduceMotion) {
            do {
                try repository?.addEmotion(level: level, subEmotion: sub, note: noteValue)
                note = ""
                selectedSubEmotion = nil
            } catch {
                // 固定文案，详情仅输出到控制台，避免向用户暴露内部路径
                print("[EmotionView] 保存情绪记录失败: \(error)")
                errorMessage = "保存失败，请重试"
            }
        }
    }
}

// MARK: - 本周趋势

/// 本周情绪区块（PRD §20.3 THIS WEEK / Mood Trend）：近 7 天 emoji 条 +
/// 趋势折线 + 一句话总结。逐日单元格以 50ms 级联入场（Motion.staggerDelay）。
private struct EmotionWeekView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    /// 卡片内容级联入场标记（onAppear 后置 true）
    @State private var contentAppeared = false

    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }
    private var daily: [(date: String, average: Double?)] {
        // 与标题「本周趋势」一致：周一对齐的本周窗口（与首页情绪快照同口径）；
        // onDays 版只返回均值数组，与日期数组一一对应，zip 回 (date, average)
        let days = DateWindows.currentWeek()
        return Array(zip(days, EmotionStats.dailyAverages(emotions, onDays: days)))
            .map { (date: $0.0, average: $0.1) }
    }

    private static let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周趋势").font(.headline)
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if EmotionStats.hasEmotionData(emotions, days: 7) {
                GlassCard(cornerRadius: 16) {
                    VStack(spacing: 14) {
                        HStack(spacing: 0) {
                            ForEach(Array(daily.enumerated()), id: \.offset) { index, item in
                                dayCell(item, index: index)
                            }
                        }
                        TrendLineView(points: daily.map(\.average), color: BrandColors.emotionPink)
                            .frame(height: 56)
                            .opacity(contentAppeared ? 1 : 0)
                            .animation(
                                Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(4)),
                                value: contentAppeared
                            )
                    }
                    .padding(16)
                }
            } else {
                Text("本周还没有情绪记录，从上方开始吧")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(Motion.softOut(reduceMotion)) { contentAppeared = true }
        }
    }

    private func dayCell(_ item: (date: String, average: Double?), index: Int) -> some View {
        VStack(spacing: 4) {
            if let average = item.average,
               let level = EmotionLevel(rawValue: max(-3, min(3, Int(average.rounded())))) {
                Text(level.emoji).font(.title3)
            } else {
                // 当日无记录：浅灰虚线圆占位
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 16, height: 16)
                    .padding(.vertical, 2)
            }
            Text(weekdayLabel(item.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: !contentAppeared && !reduceMotion ? 6 : 0)
        .animation(
            Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(index)),
            value: contentAppeared
        )
    }

    /// 一句话总结：窗口内日均值 >0.5 积极 / <-0.5 偏低落 / 其余平稳
    private var summary: String {
        let values = daily.compactMap(\.average)
        guard !values.isEmpty else { return "" }
        let mean = values.reduce(0, +) / Double(values.count)
        if mean > 0.5 { return "多数积极" }
        if mean < -0.5 { return "整体偏低落，记得照顾自己" }
        return "整体平稳"
    }

    private func weekdayLabel(_ day: String) -> String {
        guard let date = DateFormatting.parseDay(day) else { return "" }
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return "周" + Self.weekdaySymbols[weekday - 1]
    }
}

// MARK: - 近期记录

/// 近期情绪记录：自带 @Query（按创建时间倒序、限 20 条），与父视图滑杆/输入状态隔离
private struct EmotionHistoryView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var emotionEntities: [EmotionEntity]

    @State private var deletingRecord: EmotionRecord? = nil
    @State private var errorMessage: String? = nil

    init() {
        var descriptor = FetchDescriptor<EmotionEntity>(
            sortBy: [SortDescriptor(\EmotionEntity.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        _emotionEntities = Query(descriptor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("近期记录").font(.headline)
                Spacer()
                if !emotionEntities.isEmpty {
                    Text("\(emotionEntities.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if emotionEntities.isEmpty {
                Text("还没有情绪记录，从上方开始吧")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(emotionEntities.map { $0.toModel() }) { record in
                    emotionRow(record)
                }
            }
        }
        .alert("删除这条情绪记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let record = deletingRecord {
                    // 包一层动画，让行删除做柔和的消失过渡
                    Motion.animate(Motion.soft(reduceMotion), reduceMotion: reduceMotion) {
                        do { try repository?.deleteEmotion(id: record.id) }
                        catch {
                            print("[EmotionHistoryView] 删除情绪记录失败: \(error)")
                            errorMessage = "删除失败，请重试"
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func emotionRow(_ record: EmotionRecord) -> some View {
        HStack(spacing: 10) {
            Text(record.level.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.level.displayName).font(.callout.weight(.medium))
                    if let sub = record.subEmotion {
                        Text(sub.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(sub.color.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }
                if let note = record.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(record.recordDate).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("删除", role: .destructive) { deletingRecord = record }
        }
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingRecord != nil }, set: { if !$0 { deletingRecord = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

// MARK: - 情绪调色板插值

/// 七级情绪调色板的连续插值：light/dark 双变体分别线性插值，
/// 保证明暗外观下色彩过渡都无断层。
private enum EmotionPalette {
    /// value 连续（1...7），返回相邻两级之间的插值色
    static func color(for value: Double) -> Color {
        let clamped = max(1, min(7, value))
        let scaled = clamped - 1 // 0...6
        let index = min(5, Int(scaled))
        let fraction = scaled - Double(index)
        let a = EmotionLevel.allCases[index]
        let b = EmotionLevel.allCases[index + 1]
        return BrandColors.dynamic(
            light: lerpHex(a.colorHex, b.colorHex, fraction),
            dark: lerpHex(a.darkColorHex, b.darkColorHex, fraction)
        )
    }

    /// `#RRGGBB` 之间按 fraction (0...1) 做 RGB 线性插值
    private static func lerpHex(_ from: String, _ to: String, _ fraction: Double) -> String {
        let (r1, g1, b1) = rgb(from)
        let (r2, g2, b2) = rgb(to)
        let r = Int((r1 + (r2 - r1) * fraction).rounded())
        let g = Int((g1 + (g2 - g1) * fraction).rounded())
        let b = Int((b1 + (b2 - b1) * fraction).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func rgb(_ hex: String) -> (Double, Double, Double) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        return (Double((rgb >> 16) & 0xFF), Double((rgb >> 8) & 0xFF), Double(rgb & 0xFF))
    }
}
