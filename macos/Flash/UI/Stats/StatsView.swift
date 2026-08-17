import SwiftUI
import SwiftData
import Charts

/// 统计页：KPI + 情绪趋势/子情绪分布（对齐 Android StatsViewModel + EmotionStatsSection）
struct StatsView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var windowDays = 7
    /// KPI 卡片入场开关（配合逐项 delay 做 stagger）
    @State private var cardsShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 实体 → 模型只映射一次，KPI 与图表统计复用同一结果
        let logs = logEntities.map { $0.toModel() }
        let emotions = emotionEntities.map { $0.toModel() }
        let totalLogs = logs.filter { $0.category == .log }.count
        let totalIdeas = logs.filter { $0.category == .idea }.count
        let activeDays = Set(logs.map(\.recordDate) + emotions.map(\.recordDate)).count

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // KPI
                HStack(spacing: 12) {
                    kpiCard("累计日志", totalLogs, "note.text", index: 0)
                    kpiCard("累计灵感", totalIdeas, "lightbulb", index: 1)
                    kpiCard("累计情绪", emotions.count, "face.smiling", index: 2)
                    kpiCard("活跃天数", activeDays, "calendar", index: 3)
                }

                // 时间窗
                Picker("时间范围", selection: $windowDays) {
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                if EmotionStats.hasEmotionData(emotions, days: windowDays) {
                    // 日均情绪趋势
                    VStack(alignment: .leading, spacing: 8) {
                        Text("情绪趋势").font(.headline)
                        Chart {
                            RuleMark(y: .value("中性", 0))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Color(nsColor: .separatorColor))
                            ForEach(Array(EmotionStats.dailyAverages(emotions, days: windowDays)
                                .enumerated()), id: \.offset) { _, item in
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

                    // 负面子情绪分布
                    let distribution = EmotionStats.subEmotionDistribution(emotions,
                                                                           days: windowDays)
                    if !distribution.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("负面情绪构成").font(.headline)
                            Chart(distribution, id: \.name) { item in
                                BarMark(
                                    x: .value("次数", item.count),
                                    y: .value("类型", item.name)
                                )
                                .foregroundStyle(barColor(for: item.name))
                                .cornerRadius(4)
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
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if reduceMotion {
                cardsShown = true
            } else {
                withAnimation(Motion.softOut()) { cardsShown = true }
            }
        }
    }

    private func barColor(for name: String) -> Color {
        // 与 SubEmotion 配色一致（伤心/生气/难受）
        SubEmotion.allCases.first { $0.displayName == name }
            .map { $0.color } ?? .secondary
    }

    private func kpiCard(_ title: String, _ value: Int, _ icon: String, index: Int) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text("\(value)")
                .font(.title2).bold()
                .contentTransition(.opacity) // 数字变化淡变
                .animation(Motion.quick(reduceMotion), value: value)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
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
