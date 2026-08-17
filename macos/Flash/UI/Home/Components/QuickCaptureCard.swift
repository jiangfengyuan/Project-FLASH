import SwiftUI

/// 快速记录卡片：无边框多行输入 + 4 个模块胶囊按钮。
/// 纯展示型组件——草稿、可用模块与保存回调全部由外部传入。
struct QuickCaptureCard: View {
    @Binding var draft: String
    let enabledModules: Set<HomeModule>
    /// 可选的外部焦点绑定（如 Home 的 ⌘N 聚焦）；nil 表示不接管焦点
    let focus: FocusState<Bool>.Binding?
    let onSave: (HomeModule) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(draft: Binding<String>,
         enabledModules: Set<HomeModule> = [.log, .idea],
         focus: FocusState<Bool>.Binding? = nil,
         onSave: @escaping (HomeModule) -> Void) {
        self._draft = draft
        self.enabledModules = enabledModules
        self.focus = focus
        self.onSave = onSave
    }

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("快速记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("现在想记录什么？", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .modifier(OptionalFocusModifier(focus: focus))

                HStack(spacing: 8) {
                    moduleButton(.log, title: "Log", icon: "note.text")
                    moduleButton(.idea, title: "Idea", icon: "lightbulb")
                    moduleButton(.task, title: "Task", icon: "checkmark.circle")
                    moduleButton(.emotion, title: "Emotion", icon: "face.smiling")
                }
            }
            .padding(16)
        }
        .cardFloat(reduceMotion: reduceMotion)
    }

    private func moduleButton(_ module: HomeModule, title: String, icon: String) -> some View {
        let moduleEnabled = enabledModules.contains(module)
        let enabled = moduleEnabled && hasDraft
        let color = BrandColors.moduleColor(module)

        return Button {
            onSave(module)
        } label: {
            Label(title, systemImage: icon)
                .font(.callout)
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .animation(Motion.quick(reduceMotion), value: enabled)
        .help(helpText(for: module))
    }

    private func helpText(for module: HomeModule) -> String {
        guard enabledModules.contains(module) else { return "后续版本支持" }
        switch module {
        case .log: return "保存为日志"
        case .idea: return "保存为灵感"
        case .task: return "保存为任务"
        case .emotion: return "保存为情绪"
        }
    }
}

/// 有条件地应用 .focused 绑定（focus 为 nil 时原样返回）
private struct OptionalFocusModifier: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State var draft = "今天把 macOS 首页的仪表盘搭起来了"
        var body: some View {
            QuickCaptureCard(draft: $draft) { module in
                print("save:", module)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
    return PreviewHost()
}
