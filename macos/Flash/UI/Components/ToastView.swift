import SwiftUI

/// 顶部轻提示（toast）：.regularMaterial 胶囊 + 细边框 + 轻阴影。
/// 纯展示组件——出现/消失由外部用 transition + animation 控制，
/// 自动消隐由外部定时把 message 置回 nil（参考 HomeView 用法）。
struct ToastView: View {
    let message: String

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
