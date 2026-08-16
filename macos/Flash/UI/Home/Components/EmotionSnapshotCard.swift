import SwiftUI

/// Home 仪表盘右侧「情绪快照」卡片：本周整体情绪 + 一周趋势折线。
/// 纯展示组件，数据全部由外部传入；points 7 个元素对应周一到周日。
struct EmotionSnapshotCard: View {
    /// 顶部大 emoji，如 "😊"
    let emoji: String
    /// 状态标题，如 "Feeling Good"
    let title: String
    /// 模块色小字摘要，如 "本周整体偏积极"
    let summary: String
    /// 一周情绪趋势，7 个点对应周一到周日；nil 为断点
    let points: [Double?]
    /// 「查看全部」回调
    let onViewAll: () -> Void

    init(
        emoji: String,
        title: String,
        summary: String,
        points: [Double?],
        onViewAll: @escaping () -> Void = {}
    ) {
        self.emoji = emoji
        self.title = title
        self.summary = summary
        self.points = points
        self.onViewAll = onViewAll
    }

    /// 周一到周日的单字标签
    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // 顶部：标题 + 查看全部
                HStack(alignment: .firstTextBaseline) {
                    Text("情绪快照")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button("查看全部", action: onViewAll)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(BrandColors.accent)
                }

                // 中部：emoji + 标题 + 摘要
                HStack(spacing: 12) {
                    Text(emoji)
                        .font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primary)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(BrandColors.emotionPink)
                    }
                    Spacer()
                }

                // 底部：一周趋势折线 + 周一到周日标签
                TrendLineView(points: points, color: BrandColors.emotionPink)
                    .frame(height: 64)

                HStack {
                    ForEach(Self.weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    EmotionSnapshotCard(
        emoji: "😊",
        title: "Feeling Good",
        summary: "本周整体偏积极",
        points: [0.4, 0.55, 0.5, 0.7, 0.65, 0.8, 0.75],
        onViewAll: {}
    )
    .frame(width: 320)
    .padding(24)
}
