import SwiftUI

/// 情绪趋势折线图（Emotion Snapshot）：Catmull-Rom 平滑曲线 + 圆点。
/// points 每天一个点；nil 表示当天无数据（断点跳过）。全 nil 时渲染浅灰虚线占位。
/// 首次出现与数据切换时以 trim 0→1 描绘曲线、圆点 stagger 淡入（Motion.emphasize；
/// Reduce Motion 下直接完整呈现）。
struct TrendLineView: View {
    /// 每天一个点；nil 表示当天无数据（断点跳过）
    let points: [Double?]
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 曲线描绘进度（0→1）
    @State private var drawProgress: CGFloat = 0
    /// 圆点可见性开关（配合逐项 delay 做 stagger 淡入）
    @State private var dotsVisible = false

    init(points: [Double?], color: Color) {
        self.points = points
        self.color = color
    }

    /// 将 points 拆成连续的段（nil 断开），返回每段的归一化坐标。
    private func segments(in size: CGSize) -> [[CGPoint]] {
        let count = points.count
        guard count > 0, size.width > 0, size.height > 0 else { return [] }

        let values = points.compactMap { $0 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.0001) // 除零保护

        let xStep = count > 1 ? size.width / CGFloat(count - 1) : 0
        let yPadding: CGFloat = 4 // 给圆点留边距
        let usableHeight = max(size.height - yPadding * 2, 1)

        var result: [[CGPoint]] = []
        var current: [CGPoint] = []
        for (index, point) in points.enumerated() {
            if let value = point {
                let x = count > 1 ? CGFloat(index) * xStep : size.width / 2
                let ratio = (value - minValue) / range
                let y = yPadding + usableHeight * CGFloat(1 - ratio)
                current.append(CGPoint(x: x, y: y))
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// Catmull-Rom 平滑曲线（转三次贝塞尔）。单点段不画线。
    private func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    var body: some View {
        GeometryReader { proxy in
            let segs = segments(in: proxy.size)
            if segs.isEmpty {
                // 全 nil：浅灰虚线占位
                Path { path in
                    let y = proxy.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
                .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            } else {
                ZStack {
                    ForEach(Array(segs.enumerated()), id: \.offset) { segIndex, seg in
                        // 跨段连续编号，让断点后的圆点继续 stagger
                        let baseIndex = segs.prefix(segIndex).reduce(0) { $0 + $1.count }
                        smoothPath(through: seg)
                            .trim(from: 0, to: drawProgress)
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        ForEach(Array(seg.enumerated()), id: \.offset) { pointIndex, point in
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                                .opacity(dotsVisible ? 1 : 0)
                                .animation(
                                    Motion.softOut(reduceMotion)?
                                        .delay(Motion.staggerDelay(baseIndex + pointIndex)),
                                    value: dotsVisible)
                                .position(point)
                        }
                    }
                }
            }
        }
        .onAppear { replay() }
        .onChange(of: points) { _, _ in replay() }
        .accessibilityLabel("情绪趋势图")
    }

    /// 重播绘制动画。重置不进动画事务（异步触发描绘），避免首尾状态被合并导致动画丢失。
    private func replay() {
        guard !reduceMotion else {
            drawProgress = 1
            dotsVisible = true
            return
        }
        drawProgress = 0
        dotsVisible = false
        DispatchQueue.main.async {
            withAnimation(Motion.emphasize()) { drawProgress = 1 }
            dotsVisible = true // 各圆点由 .animation(value:) 带 delay 逐项淡入
        }
    }
}

#Preview {
    TrendLineView(points: [0.4, 0.6, nil, 0.8, 0.55, 0.7, 0.9], color: BrandColors.emotionPink)
        .frame(width: 240, height: 80)
        .padding()
}
