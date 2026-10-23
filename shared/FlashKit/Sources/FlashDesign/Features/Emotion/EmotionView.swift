// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore

/// 情绪页：七级情绪记录（对齐 Android EmotionViewModel）。
/// 主视觉为大 emoji：随等级 .pop 切换，名称色彩沿七级调色板连续插值（§33 Motion）。
/// 区块结构：情绪选择卡片 → 本周趋势 → 近期记录，入场按 50ms 级联错开。
public struct EmotionView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sliderValue: Double = 5 // 1...7 → veryUnhappy...slightlyHappy 默认
    @State private var selectedSubEmotion: SubEmotion? = nil
    /// 情绪强度 1–5（PRD §20 V1.1）：可选，nil = 未评；再点已选圆点取消
    @State private var intensity: Int? = nil
    @State private var note = ""
    @State private var errorMessage: String? = nil

    /// 入场标记：主卡片 / 本周趋势 / 近期记录依次出现
    @State private var heroAppeared = false
    @State private var weekAppeared = false
    @State private var historyAppeared = false

    private var selectedLevel: EmotionLevel {
        EmotionLevel.allCases[Int(sliderValue) - 1]
    }

    public init() {}

    /// 强度圆点：触屏命中框 44pt（Metrics.minTouchTarget），macOS 保持原 14pt 圆点 + 12pt 间距
    #if os(iOS)
    private let intensityHitSize: CGFloat = Metrics.minTouchTarget
    private let intensityDotSpacing: CGFloat = 0
    #else
    private let intensityHitSize: CGFloat = 14
    private let intensityDotSpacing: CGFloat = Spacing.sm
    #endif

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
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
            .padding(Spacing.lg)
            .frame(maxWidth: Metrics.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(BrandColors.pageBackground)
        .onAppear(perform: playEntranceAnimation)
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 情绪选择卡片

    private var heroCard: some View {
        GlassCard(cornerRadius: Radius.glass) {
            VStack(spacing: 20) { // 20：hero 卡内部件的宽松节奏（md 与 lg 之间）
                Text("现在感觉怎么样？")
                    .font(Typography.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 主视觉：emoji 随等级切换 .pop 过渡，名称色彩沿七级调色板连续插值
                VStack(spacing: Spacing.sm) {
                    Text(selectedLevel.emoji)
                        .scaledSystemFont(size: 64, relativeTo: .largeTitle)
                        .id(selectedLevel)
                        .transition(.pop(reduceMotion: reduceMotion))
                        .accessibilityHidden(true)

                    Text(selectedLevel.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(EmotionPalette.textColor(for: sliderValue))
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
                .frame(maxWidth: 420) // 滑杆最大宽度（几何值）
                .onChange(of: sliderValue) {
                    if !selectedLevel.isNegative { selectedSubEmotion = nil }
                }
                .accessibilityValue(selectedLevel.displayName)

                // 强度（可选，1–5 圆点行，再点一次取消；PRD §20 V1.1）
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("强度（可选）")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: intensityDotSpacing) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                intensity = (intensity == value) ? nil : value
                            } label: {
                                Circle()
                                    .fill((intensity ?? 0) >= value
                                          ? BrandColors.emotionPink
                                          : Color.primary.opacity(0.15))
                                    .frame(width: 14, height: 14) // 强度圆点尺寸（几何值）
                                    .frame(width: intensityHitSize, height: intensityHitSize)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("强度 \(value)")
                            .accessibilityAddTraits(intensity == value ? [.isSelected] : [])
                        }
                        if let intensity {
                            Text("强度 \(intensity)")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .animation(Motion.quick(reduceMotion), value: intensity)
                }
                .frame(maxWidth: 420, alignment: .leading) // 与滑杆同宽（几何值）

                // 子情绪（仅负面）
                if selectedLevel.isNegative {
                    HStack(spacing: 10) { // 10：胶囊间紧凑节奏（无对应令牌）
                        ForEach(SubEmotion.allCases, id: \.self) { sub in
                            subEmotionChip(sub)
                        }
                    }
                    .animation(Motion.quick(reduceMotion), value: selectedSubEmotion)
                    .transition(.pop(reduceMotion: reduceMotion))
                }

                HStack(spacing: 10) { // 10：输入框与按钮的紧凑节奏（无对应令牌）
                    TextField("想说点什么？（可选）", text: $note)
                        .textFieldStyle(.roundedBorder)
                    Button("记录情绪") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .frame(maxWidth: 420) // 输入行最大宽度（几何值）
            }
            .padding(Spacing.lg)
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
                .font(Typography.secondary)
                .padding(.horizontal, 14) // 胶囊横向内距（无对应令牌）
                .padding(.vertical, 6)    // 胶囊纵向内距（无对应令牌）
                .background(isOn ? sub.color.opacity(0.3)
                                 : BrandColors.cardSurface)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? sub.color
                                          : BrandColors.weakBorder,
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
        // 契约上限（与首页/菜单栏伴侣/日志/任务编辑统一口径）：超限可见提示、不入库
        guard TextLimits.fits(note) else {
            errorMessage = "内容超出 \(TextLimits.maxContentUTF16) 字上限，请删减后再保存"
            return
        }
        // 包一层动画，让下方历史列表对新增记录做柔和的插入过渡
        Motion.animate(Motion.soft(reduceMotion), reduceMotion: reduceMotion) {
            do {
                try repository?.addEmotion(level: level, subEmotion: sub, note: noteValue,
                                           intensity: intensity)
                note = ""
                selectedSubEmotion = nil
                intensity = nil
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
        VStack(alignment: .leading, spacing: 10) { // 10：标题行与卡片的紧凑节奏（无对应令牌）
            HStack(alignment: .firstTextBaseline) {
                Text("本周趋势").font(Typography.cardTitle)
                Spacer()
                Text(summary)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if EmotionStats.hasEmotionData(emotions, days: 7) {
                GlassCard(cornerRadius: Radius.cardSmall) {
                    VStack(spacing: 14) { // 14：emoji 条与折线的间距特调（无对应令牌）
                        HStack(spacing: 0) {
                            ForEach(Array(daily.enumerated()), id: \.offset) { index, item in
                                dayCell(item, index: index)
                            }
                        }
                        TrendLineView(points: daily.map(\.average), color: BrandColors.emotionPink)
                            .frame(height: 56) // 折线图固有高度（几何值）
                            .opacity(contentAppeared ? 1 : 0)
                            .animation(
                                Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(4)),
                                value: contentAppeared
                            )
                    }
                    .padding(Spacing.md)
                }
            } else {
                Text("本周还没有情绪记录，从上方开始吧")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            withAnimation(Motion.softOut(reduceMotion)) { contentAppeared = true }
        }
    }

    private func dayCell(_ item: (date: String, average: Double?), index: Int) -> some View {
        VStack(spacing: Spacing.xxs) {
            if let average = item.average,
               let level = EmotionLevel(rawValue: max(-3, min(3, Int(average.rounded())))) {
                Text(level.emoji).font(.title3)
            } else {
                // 当日无记录：浅灰虚线圆占位
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 16, height: 16) // 占位圆点尺寸（几何值）
                    .padding(.vertical, 2) // 与 emoji 行高对齐的极小内距
            }
            Text(weekdayLabel(item.date))
                .font(Typography.fine)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("近期记录").font(Typography.cardTitle)
                Spacer()
                if !emotionEntities.isEmpty {
                    Text("\(emotionEntities.count) 条")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if emotionEntities.isEmpty {
                Text("还没有情绪记录，从上方开始吧")
                    .font(Typography.secondary)
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
        HStack(spacing: 10) { // 10：emoji 与文字的紧凑节奏（无对应令牌）
            Text(record.level.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) { // 2：名称行与备注的极小间距
                HStack(spacing: 6) { // 6：名称与子情绪徽章的紧凑间距
                    Text(record.level.displayName).font(Typography.secondary.weight(.medium))
                    if let sub = record.subEmotion {
                        Text(sub.displayName)
                            .font(Typography.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2) // 徽章纵向内距：极小特调值
                            .background(sub.color.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    if let intensity = record.intensity {
                        intensityDots(intensity)
                    }
                }
                if let note = record.note, !note.isEmpty {
                    Text(note).font(Typography.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { toggleFavorite(record) } label: {
                Image(systemName: record.isFavorite == true ? "star.fill" : "star")
                    .font(Typography.caption)
                    .foregroundStyle(record.isFavorite == true
                                     ? BrandColors.ideaYellowText : .secondary)
                    .frame(minWidth: 20, minHeight: 20) // 星标命中框下限（几何值）
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(record.isFavorite == true ? "取消收藏" : "收藏")
            .accessibilityLabel(record.isFavorite == true ? "取消收藏" : "收藏")
            Text(record.recordDate).font(Typography.caption).foregroundStyle(.secondary)
        }
        .padding(10) // 行内边距：紧凑特调值（无对应令牌）
        .background(BrandColors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.field))
        .contextMenu {
            Button(record.isFavorite == true ? "取消收藏" : "收藏") { toggleFavorite(record) }
            Button("删除", role: .destructive) { deletingRecord = record }
        }
    }

    /// 强度展示：5 个小圆点，命中数着色（emotionPink），整体朗读为「强度 N」
    private func intensityDots(_ intensity: Int) -> some View {
        HStack(spacing: 3) { // 3：强度圆点的极小间距
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= intensity ? BrandColors.emotionPink
                                             : Color.primary.opacity(0.15))
                    .frame(width: 5, height: 5) // 强度圆点尺寸（几何值）
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("强度 \(intensity)")
    }

    private func toggleFavorite(_ record: EmotionRecord) {
        do { try repository?.setEmotionFavorite(id: record.id, !(record.isFavorite ?? false)) }
        catch {
            print("[EmotionHistoryView] 收藏切换失败: \(error)")
            errorMessage = "操作失败，请重试"
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
        let (light, dark) = pair(for: value)
        return BrandColors.dynamic(light: light, dark: dark)
    }

    /// 文字用变体：情绪浅色（如 #90EE90/#B0E0E6）在浅色卡片上作文字远低于 3:1，
    /// 浅色外观下向主文字色 #2D3436 插值 55% 提升可读性（仍保留同色相）；
    /// 深色变体本身为浅粉彩色，深底可读，保持原值。
    static func textColor(for value: Double) -> Color {
        let (light, dark) = pair(for: value)
        return BrandColors.dynamic(light: lerpHex(light, "#2D3436", 0.55), dark: dark)
    }

    /// value 连续（1...7），返回相邻两级插值后的 (light, dark) hex
    private static func pair(for value: Double) -> (String, String) {
        let clamped = max(1, min(7, value))
        let scaled = clamped - 1 // 0...6
        let index = min(5, Int(scaled))
        let fraction = scaled - Double(index)
        let a = EmotionLevel.allCases[index]
        let b = EmotionLevel.allCases[index + 1]
        return (lerpHex(a.colorHex, b.colorHex, fraction),
                lerpHex(a.darkColorHex, b.darkColorHex, fraction))
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
