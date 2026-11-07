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

// iOS「纸上书写」的手作元素（品牌标准 §08）：手绘线与圈、毛边、折叠信纸、便签、纸张颗粒。
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

/// 毛边线：比手绘线更碎、更短的起伏，像撕开的纸边。开放路径，只能描边
public struct TornLine: Shape {
    public var seed: String
    public var amplitude: CGFloat
    public var step: CGFloat

    public init(seed: String, amplitude: CGFloat = 1.6, step: CGFloat = 7) {
        self.seed = seed
        self.amplitude = amplitude
        self.step = step
    }

    public func path(in rect: CGRect) -> Path {
        var jitter = SeededJitter(seed: seed)
        var path = Path()
        var x = rect.minX
        path.move(to: CGPoint(x: x, y: rect.midY + jitter.next() * amplitude))
        while x < rect.maxX {
            x = min(rect.maxX, x + step * (0.7 + (jitter.next() + 1) * 0.3))
            path.addLine(to: CGPoint(x: x, y: rect.midY + jitter.next() * amplitude))
        }
        return path
    }
}

/// 纸卡外形：圆角矩形，边缘带极轻起伏；`frayed` 时底边是撕开的毛边。
/// 形状由种子决定、重绘一致；只在布局变化时重算，列表滚动不受影响
public struct PaperCardShape: Shape {
    public var seed: String
    public var cornerRadius: CGFloat
    public var frayed: Bool
    /// 三条光滑边的起伏幅度
    public var wobble: CGFloat

    public init(seed: String, cornerRadius: CGFloat, frayed: Bool = false, wobble: CGFloat = 0.6) {
        self.seed = seed
        self.cornerRadius = cornerRadius
        self.frayed = frayed
        self.wobble = wobble
    }

    public func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        var jitter = SeededJitter(seed: seed)
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        var path = Path()

        // 一条低频起伏的边：沿 start → end，法向偏移 ±wobble
        func wavyEdge(to end: CGPoint, from start: CGPoint) {
            let length = hypot(end.x - start.x, end.y - start.y)
            let segments = max(1, Int(length / 48))
            let (nx, ny) = length > 0 ? (-(end.y - start.y) / length, (end.x - start.x) / length) : (0, 0)
            for index in 1...segments {
                let t = CGFloat(index) / CGFloat(segments)
                let target = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                let midT = (CGFloat(index) - 0.5) / CGFloat(segments)
                let offset = jitter.next() * wobble
                let control = CGPoint(x: start.x + (end.x - start.x) * midT + nx * offset,
                                      y: start.y + (end.y - start.y) * midT + ny * offset)
                path.addQuadCurve(to: target, control: control)
            }
        }

        path.move(to: CGPoint(x: minX + r, y: minY))
        wavyEdge(to: CGPoint(x: maxX - r, y: minY), from: CGPoint(x: minX + r, y: minY))
        path.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
        if frayed {
            wavyEdge(to: CGPoint(x: maxX, y: maxY - 3), from: CGPoint(x: maxX, y: minY + r))
            // 底边：短促不规则的撕口
            var x = maxX
            while x > minX {
                x = max(minX, x - 7 * (0.7 + (jitter.next() + 1) * 0.3))
                path.addLine(to: CGPoint(x: x, y: maxY - 2.4 + jitter.next() * 2.4))
            }
            wavyEdge(to: CGPoint(x: minX, y: minY + r), from: CGPoint(x: minX, y: maxY - 3))
        } else {
            wavyEdge(to: CGPoint(x: maxX, y: maxY - r), from: CGPoint(x: maxX, y: minY + r))
            path.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY), control: CGPoint(x: maxX, y: maxY))
            wavyEdge(to: CGPoint(x: minX + r, y: maxY), from: CGPoint(x: maxX - r, y: maxY))
            path.addQuadCurve(to: CGPoint(x: minX, y: maxY - r), control: CGPoint(x: minX, y: maxY))
            wavyEdge(to: CGPoint(x: minX, y: minY + r), from: CGPoint(x: minX, y: maxY - r))
        }
        path.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
        path.closeSubpath()
        return path
    }
}

/// 分隔线：iOS 横向为毛边、纵向为手绘线；macOS 为系统 Divider
public struct FlashDivider: View {
    public var seed: String
    public var axis: Axis

    public init(seed: String = "divider", axis: Axis = .horizontal) {
        self.seed = seed
        self.axis = axis
    }

    public var body: some View {
        #if os(iOS)
        Group {
            if axis == .horizontal {
                TornLine(seed: seed)
                    .stroke(BrandColors.weakBorder, style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
            } else {
                HandDrawnLine(seed: seed, amplitude: 0.8, axis: axis)
                    .stroke(BrandColors.weakBorder, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
        .frame(width: axis == .vertical ? 3 : nil, height: axis == .horizontal ? 4 : nil)
        .accessibilityHidden(true)
        #else
        Divider()
        #endif
    }
}

#if os(iOS)
/// 撕开的区块断口：一条窄窄的羊皮纸带，上下都是毛边
public struct TornSectionBreak: View {
    public var seed: String

    public init(seed: String) { self.seed = seed }

    public var body: some View {
        ZStack {
            PaperCardShape(seed: seed, cornerRadius: 1, frayed: true, wobble: 1)
                .fill(BrandColors.parchment.opacity(0.55))
            TornLine(seed: seed + "·top", amplitude: 1.2)
                .stroke(BrandColors.weakBorder, style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// 折角：信纸右上角折起的小三角（从右到左时随布局翻转）
private struct DogEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 按下时轻微下陷（拟物按压：缩小 + 内影），减弱动态时只有内影
public struct PaperPressStyle: ButtonStyle {
    public var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = 999) { self.cornerRadius = cornerRadius }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BrandColors.shadowTint.opacity(configuration.isPressed ? 0.10 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.quick(reduceMotion), value: configuration.isPressed)
    }
}

private struct FoldedLetterModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                // 折痕：一暗一亮两条细线，只作装饰，压在内容之下
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Rectangle().fill(BrandColors.shadowTint.opacity(0.07)).frame(height: 0.75)
                        Rectangle().fill(BrandColors.cardSurface.opacity(0.8)).frame(height: 0.75)
                    }
                    .offset(y: proxy.size.height * 0.5)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                DogEar()
                    .fill(BrandColors.parchment)
                    .frame(width: 22, height: 22)
                    .shadow(color: BrandColors.shadowTint.opacity(0.14), radius: 3, x: -1, y: 2)
                    .flipsForRightToLeftLayoutDirection(true)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityElement(children: .contain)
    }
}

private struct StickyStackModifier: ViewModifier {
    let seed: String
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        var jitter = SeededJitter(seed: seed)
        let angle = Double(jitter.next()) * 1.4
        let dx = jitter.next() * 3
        return content.background {
            PaperCardShape(seed: seed + "·under", cornerRadius: cornerRadius, wobble: 1)
                .fill(BrandColors.parchment.opacity(0.7))
                .rotationEffect(.degrees(angle == 0 ? 1 : angle))
                .offset(x: dx, y: 4)
                .accessibilityHidden(true)
        }
    }
}

private struct VellumModifier<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                shape.fill(BrandColors.cardSurface.opacity(reduceTransparency ? 1 : 0.92))
                shape.stroke(BrandColors.weakBorder, lineWidth: 0.75)
            }
        }
    }
}
#endif

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

    /// 纸卡容器：iOS 为带起伏的纸卡 + 细边 + 弥散暖影（frayed 时底边撕开）；macOS 为圆角实色卡
    @ViewBuilder
    public func flashPaperCard(seed: String, cornerRadius: CGFloat = Radius.card, frayed: Bool = false) -> some View {
        #if os(iOS)
        let shape = PaperCardShape(seed: seed, cornerRadius: cornerRadius, frayed: frayed)
        self.background { shape.fill(BrandColors.cardSurface) }
            .overlay { shape.stroke(BrandColors.weakBorder, lineWidth: 0.75) }
            .clipShape(shape)
            .flashCardShadow()
        #else
        self.background(BrandColors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        #endif
    }

    /// 折叠信纸：折痕 + 折角（iOS）；macOS 不绘制
    @ViewBuilder
    public func flashFoldedLetter(cornerRadius: CGFloat = Radius.card) -> some View {
        #if os(iOS)
        modifier(FoldedLetterModifier(cornerRadius: cornerRadius))
        #else
        self
        #endif
    }

    /// 叠放便签：身后错开一张羊皮纸底页（iOS）；macOS 不绘制
    @ViewBuilder
    public func flashStickyStack(seed: String, cornerRadius: CGFloat = Radius.row) -> some View {
        #if os(iOS)
        modifier(StickyStackModifier(seed: seed, cornerRadius: cornerRadius))
        #else
        self
        #endif
    }

    /// 硫酸纸：浮动表面的半透明纸（≥ 92% 不透明，减弱透明度时不透明）；macOS 用卡面实色
    @ViewBuilder
    public func flashVellum<S: Shape>(in shape: S) -> some View {
        #if os(iOS)
        modifier(VellumModifier(shape: shape))
        #else
        self.background(shape.fill(BrandColors.cardSurface))
        #endif
    }

    /// 页面底：iOS 为纸张底色 + 纤维颗粒；macOS 等价于 `.background(BrandColors.pageBackground)`
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
/// 纸张底：底色 + 平铺的纤维颗粒贴图（tools/design/generate_paper_assets.py 生成，三端同一张）
private struct PaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            BrandColors.pageBackground
            if let grain = colorScheme == .dark ? PaperGrain.dark : PaperGrain.light {
                Image(uiImage: grain).resizable(resizingMode: .tile)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum PaperGrain {
    static let light = load("paper_grain_light")
    static let dark = load("paper_grain_dark")

    /// 贴图 256px 对应 128pt
    private static func load(_ name: String) -> UIImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data, scale: 2)
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
