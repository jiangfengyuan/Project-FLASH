import SwiftUI

/// 编辑记录 sheet：内容 / 标签 / 重要度
struct LogEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let log: LogItem
    /// 标题（新建场景传「新建日志」/「新建灵感」，默认保持编辑语义）
    let title: String
    let onSave: (LogItem) -> Void

    @State private var content: String
    @State private var colorTag: ColorTag
    @State private var importance: Int

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

            Picker("标签", selection: $colorTag) {
                ForEach(ColorTag.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            Stepper("重要度：\(importance)", value: $importance, in: 0...4)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    var updated = log
                    updated.content = content
                    updated.colorTag = colorTag
                    updated.importance = importance
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
