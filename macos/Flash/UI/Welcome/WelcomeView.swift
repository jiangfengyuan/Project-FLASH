import SwiftUI

/// 首次启动欢迎页（对应 Android WelcomeScreen）。完成后 setWelcomed。
struct WelcomeView: View {
    let onFinish: () -> Void

    private let pages: [(emoji: String, title: String, subtitle: String)] = [
        ("⚡️", "欢迎来到 Flash", "一闪而过的想法，值得被记住"),
        ("📝", "随手记录", "日志与灵感，一键即达"),
        ("😊", "情绪觉察", "七级情绪记录，看见自己的变化"),
    ]

    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(pages[page].emoji).font(.system(size: 64))
            Text(pages[page].title).font(.title).bold()
            Text(pages[page].subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                if page < pages.count - 1 {
                    Button("下一步") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用") { onFinish() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(width: 480, height: 420)
        .padding()
    }
}
