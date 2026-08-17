import SwiftUI

/// Flash 动效系统 —— PRD §33 Motion Design
///
/// 关键词：**Soft / Fast / Playful**
/// 手法：Fade / Scale / Blur Transition / Card Float / Icon Bounce / Gradient Shift
/// 禁止：长时间动画、大幅弹跳、大量粒子、页面晃动、阻塞用户操作
///
/// 使用约定：所有动效必须尊重 Reduce Motion。
/// ```swift
/// @Environment(\.accessibilityReduceMotion) private var reduceMotion
///
/// .animation(Motion.soft(reduceMotion), value: someState)
/// .transition(.appear(reduceMotion: reduceMotion))
/// Motion.animate(.spring(), reduceMotion: reduceMotion) { isOn = true }
/// ```
enum Motion {

    // MARK: - 时长 token

    /// 微反馈：hover、选中态、图标 bounce
    static let durationFast: Double = 0.15
    /// 标准过渡：内容出现/消失、列表内容切换
    static let durationBase: Double = 0.22
    /// 强调过渡：卡片入场、图表绘制、月份切换
    static let durationSlow: Double = 0.32

    // MARK: - 曲线（reduceMotion 为 true 时返回 nil，即瞬变）

    /// 快速 easeOut：即时反馈
    static func quick(_ rm: Bool = false) -> Animation? { rm ? nil : .easeOut(duration: durationFast) }

    /// 标准 easeInOut：内容切换的默认曲线
    static func soft(_ rm: Bool = false) -> Animation? { rm ? nil : .easeInOut(duration: durationBase) }

    /// 标准 easeOut：入场/出现
    static func softOut(_ rm: Bool = false) -> Animation? { rm ? nil : .easeOut(duration: durationBase) }

    /// 慢速 easeOut：强调性入场
    static func emphasize(_ rm: Bool = false) -> Animation? { rm ? nil : .easeOut(duration: durationSlow) }

    /// 轻弹簧：卡片浮起、小部件回弹。阻尼 ≥ 0.8，避免大幅弹跳
    static func spring(_ rm: Bool = false) -> Animation? {
        rm ? nil : .spring(response: 0.32, dampingFraction: 0.82)
    }

    /// 图标 bounce：仅小幅度使用（如成功反馈）
    static func bounce(_ rm: Bool = false) -> Animation? {
        rm ? nil : .spring(response: 0.36, dampingFraction: 0.68)
    }

    /// Reduce Motion 下的保底：极短淡变，状态切换仍可感知但不产生位移
    static func reducedFade(_ rm: Bool) -> Animation? {
        rm ? .easeOut(duration: durationFast) : nil
    }

    // MARK: - 工具

    /// 依次入场延迟：每项 50ms，上限 0.3s（防止长列表尾项过晚出现）
    static func staggerDelay(_ index: Int) -> Double {
        min(Double(index) * 0.05, 0.3)
    }

    /// withAnimation 的 Reduce-Motion 包装
    static func animate<R>(_ animation: Animation? = nil, reduceMotion rm: Bool = false, _ body: () -> R) -> R {
        if rm { return body() }
        return withAnimation(animation ?? .easeInOut(duration: durationBase), body)
    }
}

// MARK: - 过渡

extension AnyTransition {
    /// 轻量出现：淡入 + 微上移 6pt（页面、区块、空状态）
    static func appear(reduceMotion rm: Bool) -> AnyTransition {
        rm ? .opacity : .opacity.combined(with: .offset(y: 6))
    }

    /// 卡片入场：淡入 + 微缩放 0.96
    static func card(reduceMotion rm: Bool) -> AnyTransition {
        rm ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    /// 弹出反馈：淡入 + 缩放 0.94 + 微上浮（Toast、浮层）
    static func pop(reduceMotion rm: Bool) -> AnyTransition {
        rm ? .opacity : .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
    }
}

// MARK: - 悬停浮起

extension View {
    /// Card Float：悬停时上移 2pt 并落下柔和阴影。用于可交互卡片。
    /// 不阻塞操作、位移极小，符合 PRD 动效约束。
    func cardFloat(reduceMotion rm: Bool) -> some View {
        modifier(CardFloatModifier(reduceMotion: rm))
    }
}

private struct CardFloatModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .offset(y: hovering && !reduceMotion ? -2 : 0)
            .shadow(color: .black.opacity(hovering && !reduceMotion ? 0.14 : 0), radius: 10, y: 5)
            .animation(Motion.spring(reduceMotion), value: hovering)
            .onHover { hovering = $0 }
    }
}
