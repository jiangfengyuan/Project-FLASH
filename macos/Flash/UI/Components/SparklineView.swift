import SwiftUI

/// 统计卡片底部的迷你柱状图（参考稿约 7 根圆角细柱）。
/// 内部归一化到最大值；空数据渲染低矮占位柱，不崩溃。
struct SparklineView: View {
    let values: [Double]
    let color: Color

    init(values: [Double], color: Color) {
        self.values = values
        self.color = color
    }

    /// 归一化后的柱高比例（0...1）。空数据/全零时给低矮占位高度。
    private var normalized: [Double] {
        guard !values.isEmpty else { return [0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12] }
        let maxValue = values.max() ?? 0
        guard maxValue > 0 else { return values.map { _ in 0.12 } }
        return values.map { max($0 / maxValue, 0.08) } // 保底可见的最小高度
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { _, ratio in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 4, height: max(proxy.size.height * ratio, 2))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

#Preview {
    SparklineView(values: [2, 5, 3, 8, 4, 6, 7], color: BrandColors.logPurple)
        .frame(width: 80, height: 28)
        .padding()
}
