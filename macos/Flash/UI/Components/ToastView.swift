import SwiftUI

/// 顶部轻提示（toast）：.regularMaterial 胶囊 + 细边框 + 轻阴影。
/// 出现/消失过渡内置为 FlashMotion `.pop`（淡入 + 缩放 0.94，锚点顶部），
/// 尊重 Reduce Motion。已实测：SwiftUI 会采用被插入视图 body 根部的 transition，
/// 因此调用方只需用 `Motion.animate`/`withAnimation` 切换 message 即可，
/// 不要再叠加自己的 `.transition`（会与内置过渡复合）。
/// 自动消隐由外部定时把 message 置回 nil（参考 HomeView 用法）。
struct ToastView: View {
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .accessibilityLabel(message)
            .transition(.pop(reduceMotion: reduceMotion))
    }
}

#Preview {
    VStack(spacing: 16) {
        ToastView(message: "✓ 已保存到日志")
        ToastView(message: "✓ 已保存到灵感")
    }
    .padding(24)
    .frame(width: 360, height: 160)
}
