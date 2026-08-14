import SwiftUI
import SwiftData
import Charts

/// 统计页：KPI + 情绪趋势/子情绪分布（对齐 Android StatsViewModel + EmotionStatsSection）
struct StatsView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    @State private var windowDays = 7

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    private var totalLogs: Int { logs.filter { $0.category == .log }.count }
    private var totalIdeas: Int { logs.filter { $0.category == .idea }.count }
    private var activeDays: Int {
        Set(logs.map(\.recordDate) + emotions.map(\.recordDate)).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // KPI
                HStack(spacing: 12) {
                    kpiCard("累计日志", totalLogs, "note.text")
                    kpiCard("累计灵感", totalIdeas, "lightbulb")
                    kpiCard("累计情绪", emotions.count, "face.smiling")
                    kpiCard("活跃天数", activeDays, "calendar")
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
                    .animation(.easeInOut(duration: 0.3), value: windowDays)

                    // 负面子情绪分布
                    let distribution = EmotionStats.subEmotionDistribution(emotions,
                                                                           days: windowDays)
                    if !distribution.isEmpty {
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
                        .animation(.easeInOut(duration: 0.3), value: windowDays)
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
    }

    private func barColor(for name: String) -> Color {
        // 与 SubEmotion 配色一致（伤心/生气/难受）
        SubEmotion.allCases.first { $0.displayName == name }
            .map { $0.color } ?? .secondary
    }

    private func kpiCard(_ title: String, _ value: Int, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(nsColor: .controlAccentColor))
            Text("\(value)").font(.title2).bold()
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
    }
}
