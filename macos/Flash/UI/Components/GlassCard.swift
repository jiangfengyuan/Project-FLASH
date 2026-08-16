import SwiftUI

/// Aero 风格可复用卡片容器：浅色下接近白色的柔和表面，深色下用深色材质。
/// 内容优先于玻璃效果——只用极轻的材质与细边框，不做重模糊。
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    private let content: Content

    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    private var surface: some ShapeStyle {
        // 浅色：极浅灰白；深色：深色控件底，两者都足够「内容优先」
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor)
            : Color(nsColor: .controlBackgroundColor).mix(with: .white, by: 0.55)
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
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, y: 2)
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
