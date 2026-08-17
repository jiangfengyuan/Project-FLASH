import SwiftUI

/// 编辑记录 sheet：内容 / 标签 / 重要度
struct LogEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let log: LogItem
    /// 标题（新建场景传「新建日志」/「新建灵感」，默认保持编辑语义）
    let title: String
    let onSave: (LogItem) -> Void

    @State private var content: String
    @State private var colorTag: ColorTag
    @State private var importance: Int
    /// 分区入场 stagger 开关
    @State private var appeared = false
    /// 保存成功后的勾选反馈（闪现后自动关闭，不阻塞）
    @State private var saved = false

    init(log: LogItem, title: String = "编辑记录", onSave: @escaping (LogItem) -> Void) {
        self.log = log
        self.title = title
        self.onSave = onSave
        _content = State(initialValue: log.content)
        _colorTag = State(initialValue: log.colorTag)
        _importance = State(initialValue: log.importance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
                .staggeredIn(index: 0, appeared: appeared, reduceMotion: reduceMotion)

            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 120)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .staggeredIn(index: 1, appeared: appeared, reduceMotion: reduceMotion)

            Picker("标签", selection: $colorTag) {
                ForEach(ColorTag.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .staggeredIn(index: 2, appeared: appeared, reduceMotion: reduceMotion)

            Stepper("重要度：\(importance)", value: $importance, in: 0...4)
                .staggeredIn(index: 3, appeared: appeared, reduceMotion: reduceMotion)

            HStack {
                Spacer()
                if saved {
                    // 保存成功：Motion.bounce 勾选反馈（0.45s 后自动关闭）
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(BrandColors.accent)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Button("取消") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("保存") { save() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .staggeredIn(index: 4, appeared: appeared, reduceMotion: reduceMotion)
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { appeared = true }
    }

    private func save() {
        var updated = log
        updated.content = content
        updated.colorTag = colorTag
        updated.importance = importance
        onSave(updated)
        // 勾选反馈不阻塞关闭：bounce 入场后短暂停留即 dismiss
        Motion.animate(Motion.bounce(), reduceMotion: reduceMotion) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
    }
}

/// sheet 分区依次入场：淡入 + 微上移，延迟走 Motion.staggerDelay
private struct SheetStaggerModifier: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 6)
            .animation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(index)),
                       value: appeared)
    }
}

private extension View {
    func staggeredIn(index: Int, appeared: Bool, reduceMotion: Bool) -> some View {
        modifier(SheetStaggerModifier(index: index, appeared: appeared, reduceMotion: reduceMotion))
    }
}
