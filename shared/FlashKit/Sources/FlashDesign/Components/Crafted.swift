// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
#if os(iOS)
import UIKit
#endif

// iOS「暖调手作」主题的手绘元素（品牌标准 §08）：略带起伏的线、两笔勾成的圈、纸张颗粒。
// 抖动由种子字符串决定（同一元素每次重绘形状一致，滚动时不会「抖」）；
// macOS 下 FlashDivider / flashPageBackground 与原生 Divider / 纯色底完全等价。

/// 种子确定的伪随机序列（FNV-1a 散列 + SplitMix64），只用于装饰形状
struct SeededJitter {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        state = hash
    }

    /// [-1, 1] 区间的下一个值
    mutating func next() -> CGFloat {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return CGFloat(Double(z >> 11) / Double(1 << 53)) * 2 - 1
    }
}

/// 手绘线：沿长边略带起伏，两端各有一点不齐。用 `.stroke(style: .init(lineWidth:, lineCap: .round))` 描边
public struct HandDrawnLine: Shape {
    public var seed: String
    /// 起伏幅度（pt）
    public var amplitude: CGFloat
    public var axis: Axis

    public init(seed: String, amplitude: CGFloat = 1.1, axis: Axis = .horizontal) {
        self.seed = seed
        self.amplitude = amplitude
        self.axis = axis
    }

    public func path(in rect: CGRect) -> Path {
        var jitter = SeededJitter(seed: seed)
        let length = axis == .horizontal ? rect.width : rect.height
        // 每 ~36pt 一个控制点：够自然又不至于成波浪线
        let segments = max(2, Int(length / 36))
        func point(_ t: CGFloat, _ offset: CGFloat) -> CGPoint {
            axis == .horizontal
                ? CGPoint(x: rect.minX + t * rect.width, y: rect.midY + offset)
                : CGPoint(x: rect.midX + offset, y: rect.minY + t * rect.height)
        }
        // 起笔、收笔各缩进一点点，像手画时没对齐端点
        let startInset = abs(jitter.next()) * 0.015
        let endInset = abs(jitter.next()) * 0.02
        var path = Path()
        var previous = point(startInset, jitter.next() * amplitude)
        path.move(to: previous)
        for index in 1...segments {
            let t = startInset + (1 - startInset - endInset) * CGFloat(index) / CGFloat(segments)
            let next = point(t, jitter.next() * amplitude)
            let control = CGPoint(x: (previous.x + next.x) / 2 + (axis == .vertical ? jitter.next() * amplitude : 0),
                                  y: (previous.y + next.y) / 2 + (axis == .horizontal ? jitter.next() * amplitude : 0))
            path.addQuadCurve(to: next, control: control)
            previous = next
        }
        return path
    }
}

/// 手绘圈：一笔略不圆的椭圆，收笔越过起点一点（不闭合得严丝合缝）
public struct HandDrawnCircle: Shape {
    public var seed: String
    /// 半径抖动比例
    public var wobble: CGFloat

    public init(seed: String, wobble: CGFloat = 0.035) {
        self.seed = seed
        self.wobble = wobble
    }

    public func path(in rect: CGRect) -> Path {
        var jitter = SeededJitter(seed: seed)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2, ry = rect.height / 2
        let start = jitter.next() * .pi
        // 多画约 18°，形成手绘的「收笔搭头」
        let sweep = 2 * CGFloat.pi + .pi / 10
        let steps = 48
        // 低频起伏：正弦叠加种子相位，曲线保持平滑
        let phase = jitter.next() * .pi
        var path = Path()
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let angle = start + sweep * progress
            let scale = 1 + wobble * sin(angle * 2 + phase) + wobble * 0.5 * progress
            let p = CGPoint(x: center.x + cos(angle) * rx * scale,
                            y: center.y + sin(angle) * ry * scale)
            step == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        return path
    }
}

/// 图标后的手绘圈底：淡色填充 + 两笔错开的描边
public struct HandDrawnRing: View {
    public let seed: String
    public let tint: Color

    public init(seed: String, tint: Color) {
        self.seed = seed
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.12)).padding(4)
            HandDrawnCircle(seed: seed)
                .stroke(tint.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            HandDrawnCircle(seed: seed + "·2", wobble: 0.05)
                .stroke(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(8))
        }
        .accessibilityHidden(true)
    }
}

/// 分隔线：iOS 为暖色手绘线，macOS 为系统 Divider
public struct FlashDivider: View {
    public var seed: String
    public var axis: Axis

    public init(seed: String = "divider", axis: Axis = .horizontal) {
        self.seed = seed
        self.axis = axis
    }

    public var body: some View {
        #if os(iOS)
        HandDrawnLine(seed: seed, amplitude: 0.8, axis: axis)
            .stroke(BrandColors.weakBorder, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            .frame(width: axis == .vertical ? 3 : nil, height: axis == .horizontal ? 3 : nil)
            .accessibilityHidden(true)
        #else
        Divider()
        #endif
    }
}

extension View {
    /// 标题下的手绘下划线（iOS）；macOS 不绘制
    @ViewBuilder
    public func flashHandUnderline(seed: String, color: Color = BrandColors.brandPrimary,
                                   widthFraction: CGFloat = 0.6) -> some View {
        #if os(iOS)
        self.background(alignment: .bottomLeading) {
            GeometryReader { proxy in
                HandDrawnLine(seed: seed, amplitude: 1.4)
                    .stroke(color.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: proxy.size.width * widthFraction, height: 6)
                    .offset(y: proxy.size.height - 1)
            }
            .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

    /// 页面底：iOS 为纸张底色 + 极淡颗粒；macOS 等价于 `.background(BrandColors.pageBackground)`
    @ViewBuilder
    public func flashPageBackground() -> some View {
        #if os(iOS)
        self.background { PaperBackground().ignoresSafeArea() }
        #else
        self.background(BrandColors.pageBackground)
        #endif
    }
}

#if os(iOS)
/// 纸张底：底色 + 平铺的确定性颗粒纹理（各外观一张 128pt 贴图，只生成一次）
private struct PaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            BrandColors.pageBackground
            Image(uiImage: colorScheme == .dark ? PaperGrain.dark : PaperGrain.light)
                .resizable(resizingMode: .tile)
                .opacity(colorScheme == .dark ? 0.03 : 0.045)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum PaperGrain {
    static let light = make(ink: UIColor(red: 0.23, green: 0.16, blue: 0.11, alpha: 1))
    static let dark = make(ink: UIColor(white: 1, alpha: 1))

    private static func make(ink: UIColor) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            var jitter = SeededJitter(seed: "flash-paper")
            let cg = context.cgContext
            // 细颗粒
            for _ in 0..<2200 {
                let x = (jitter.next() + 1) / 2 * size.width
                let y = (jitter.next() + 1) / 2 * size.height
                let alpha = 0.25 + (jitter.next() + 1) / 2 * 0.75
                cg.setFillColor(ink.withAlphaComponent(alpha).cgColor)
                cg.fill(CGRect(x: x, y: y, width: 0.5, height: 0.5))
            }
            // 少量纤维短痕
            cg.setLineWidth(0.35)
            for _ in 0..<40 {
                let x = (jitter.next() + 1) / 2 * size.width
                let y = (jitter.next() + 1) / 2 * size.height
                let angle = jitter.next() * .pi
                let length = 2 + (jitter.next() + 1) * 2.5
                cg.setStrokeColor(ink.withAlphaComponent(0.6).cgColor)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                cg.strokePath()
            }
        }
    }
}
#endif

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("早上好")
            .flashPageTitle()
            .flashHandUnderline(seed: "greeting")
        FlashDivider()
        HStack(spacing: Spacing.lg) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(BrandColors.brandPrimary)
                .frame(width: 72, height: 72)
                .background { HandDrawnRing(seed: "preview", tint: BrandColors.brandPrimary) }
            FlashDivider(axis: .vertical).frame(height: 44)
            Image(systemName: "lightbulb")
                .font(.title)
                .foregroundStyle(BrandColors.ideaYellowText)
                .frame(width: 72, height: 72)
                .background { HandDrawnRing(seed: "idea", tint: BrandColors.ideaYellow) }
        }
    }
    .padding(Spacing.xl)
    .flashPageBackground()
}
