import SwiftUI

/// 本周洞察卡片：一句结论式洞察 + 7 天柱状趋势。
/// 纯展示型组件，数据全部由外部传入；图表用 SparklineView（accent 统一色，不支持单柱高亮）。
struct InsightOfWeekCard: View {
    let headline: String
    let detail: String
    let trend: [Double]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(headline: String, detail: String, trend: [Double]) {
        self.headline = headline
        self.detail = detail
        self.trend = trend
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.caption)
                            .foregroundStyle(BrandColors.accent)
                        Text("本周洞察")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }

                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                SparklineView(values: trend, color: BrandColors.accent)
                    .frame(width: 64, height: 32)
            }
            .padding(16)
        }
        .cardFloat(reduceMotion: reduceMotion)
    }
}

#Preview {
    InsightOfWeekCard(
        headline: "周四是你最活跃的一天。",
        detail: "继续保持！",
        trend: [2, 4, 3, 8, 5, 6, 4]
    )
    .frame(width: 320)
    .padding(24)
}
