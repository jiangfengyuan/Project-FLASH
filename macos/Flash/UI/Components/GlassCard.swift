import SwiftUI

/// Aero 风格可复用卡片容器：浅色下接近白色的柔和表面，深色下用深色材质。
/// 内容优先于玻璃效果——只用极轻的材质与细边框，不做重模糊。
/// hover 微反馈默认关闭，由调用方通过 `hoverFeedback: true` 开启（位移浮起用
/// `.cardFloat(reduceMotion:)`，同样由调用方决定）；开启后仅边框微亮 + 阴影略深，不位移。
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cornerRadius: CGFloat
    let hoverFeedback: Bool
    private let content: Content

    @State private var hovering = false

    init(cornerRadius: CGFloat = 20, hoverFeedback: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.hoverFeedback = hoverFeedback
        self.content = content()
    }

    private var surface: some ShapeStyle {
        // 浅色：极浅灰白；深色：深色控件底，两者都足够「内容优先」
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor)
            : Color(nsColor: .controlBackgroundColor).mix(with: .white, by: 0.55)
    }

    /// 细边框：深色下略提不透明度保证边缘清晰；hover 反馈开启时再微亮
    private var borderOpacity: Double {
        let base = colorScheme == .dark ? 0.65 : 0.5
        return hovering && hoverFeedback ? base + 0.25 : base
    }

    private var shadowOpacity: Double {
        let base = colorScheme == .dark ? 0.25 : 0.06
        return hovering && hoverFeedback ? base + (colorScheme == .dark ? 0.05 : 0.03) : base
    }

    var body: some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(surface)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(borderOpacity), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: hovering && hoverFeedback ? 10 : 8,
                y: hovering && hoverFeedback ? 3 : 2
            )
            .onHover { if hoverFeedback { hovering = $0 } }
            .animation(Motion.quick(reduceMotion), value: hovering)
    }
}

#Preview {
    GlassCard {
        VStack(alignment: .leading, spacing: 8) {
            Text("GlassCard")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text("内容优先，玻璃效果只做点缀。")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .padding(16)
    }
    .padding(24)
}
