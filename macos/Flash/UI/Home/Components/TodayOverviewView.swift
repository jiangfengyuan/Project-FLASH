import SwiftUI

/// 「今日概览」单张卡片的数据（纯展示，由外部组装好文本传入）。
/// id 取 module（各卡模块唯一）：stats 数组每次重算都整体重建，
/// 若用随机 UUID 会让 ForEach 身份不稳、卡片反复销毁重建。
struct OverviewStat: Identifiable {
    var id: HomeModule { module }
    let module: HomeModule
    let valueText: String   // 大号数字如 "03"，情绪卡为 emoji
    let title: String       // 副标题如 "Logs"，情绪卡为情绪名
    let trend: [Double]     // 底部迷你柱状图数据
}

/// Home 顶部横向 4 张统计卡片：log / idea / task / emotion
struct TodayOverviewView: View {
    let stats: [OverviewStat]

    init(stats: [OverviewStat]) {
        self.stats = stats
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(stats) { stat in
                StatCard(stat: stat)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct StatCard: View {
    let stat: OverviewStat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var moduleColor: Color { BrandColors.moduleColor(stat.module) }

    private var iconName: String {
        switch stat.module {
        case .log: return "note.text"
        case .idea: return "lightbulb"
        case .task: return "checkmark.circle"
        case .emotion: return "heart"
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(moduleColor)

                Text(stat.valueText)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)
                    // 数字变化滚动过渡（macOS 14+；工程最低 macOS 15，无需降级判断）
                    // 减弱动态时 Motion.soft 返回 nil，contentTransition 无动画直接替换
                    .contentTransition(.numericText())
                    .animation(Motion.soft(reduceMotion), value: stat.valueText)

                Text(stat.title)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)

                SparklineView(values: stat.trend, color: moduleColor)
                    .frame(height: 24)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    TodayOverviewView(stats: [
        OverviewStat(module: .log, valueText: String(format: "%02d", 3), title: "Logs",
                     trend: [2, 4, 3, 6, 5, 8, 3]),
        OverviewStat(module: .idea, valueText: String(format: "%02d", 5), title: "Ideas",
                     trend: [1, 3, 2, 5, 4, 7, 5]),
        OverviewStat(module: .task, valueText: String(format: "%02d", 2), title: "Tasks",
                     trend: [3, 2, 5, 4, 6, 3, 2]),
        OverviewStat(module: .emotion, valueText: "😊", title: "平静",
                     trend: [3, 4, 2, 5, 4, 3, 4]),
    ])
    .padding(20)
}
