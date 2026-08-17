import SwiftUI

/// 首次启动欢迎页（对应 Android WelcomeScreen）。完成后 setWelcomed。
/// 翻页：旧页以 .appear 反向过渡淡出；新页 emoji/标题/副标题按 50ms 级联
/// stagger 入场（emoji 附带 .card 式微缩放）。所有动效尊重 Reduce Motion。
struct WelcomeView: View {
    let onFinish: () -> Void

    private let pages: [(emoji: String, title: String, subtitle: String)] = [
        ("⚡️", "欢迎来到 Flash", "一闪而过的想法，值得被记住"),
        ("📝", "随手记录", "日志与灵感，一键即达"),
        ("😊", "情绪觉察", "七级情绪记录，看见自己的变化"),
    ]

    @State private var page = 0
    /// 已完成入场的页码：驱动当前页内容逐项 stagger 入场（-1 表示尚未入场）
    @State private var shownPage = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLastPage: Bool { page == pages.count - 1 }
    private var shown: Bool { shownPage == page }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text(pages[page].emoji)
                    .font(.system(size: 64))
                    .padding(.bottom, 8)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.96)
                    .animation(entrance(0), value: shownPage)
                Text(pages[page].title)
                    .font(.title).bold()
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown || reduceMotion ? 0 : 6)
                    .animation(entrance(1), value: shownPage)
                Text(pages[page].subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown || reduceMotion ? 0 : 6)
                    .animation(entrance(2), value: shownPage)
            }
            .id(page)
            .transition(.appear(reduceMotion: reduceMotion))
            .onAppear { shownPage = page }
            Spacer()
            HStack {
                if !isLastPage {
                    Button("下一步") { advance() }
                        .buttonStyle(.borderedProminent)
                        .modifier(HoverZoomModifier(reduceMotion: reduceMotion))
                } else {
                    Button("开始使用") { onFinish() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .modifier(HoverZoomModifier(reduceMotion: reduceMotion))
                }
            }
            .padding(.bottom, 32)
        }
        .frame(width: 480, height: 420)
        .padding()
    }

    /// 逐项入场曲线：标准 easeOut + 级联延迟；减弱动态时返回 nil（瞬变）
    private func entrance(_ index: Int) -> Animation? {
        Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(index))
    }

    private func advance() {
        Motion.animate(Motion.soft(), reduceMotion: reduceMotion) { page += 1 }
    }
}

/// CTA 按钮 hover 微反馈：轻微放大，Motion.quick 回弹；减弱动态时关闭。
private struct HoverZoomModifier: ViewModifier {
    let reduceMotion: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering && !reduceMotion ? 1.04 : 1)
            .animation(Motion.quick(reduceMotion), value: hovering)
            .onHover { hovering = $0 }
    }
}
