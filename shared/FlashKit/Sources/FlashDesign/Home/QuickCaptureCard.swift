// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 快速捕捉卡：SegmentedPicker 切换「日志 / 灵感」+ 无边框多行输入 + 主操作「保存」。
/// 实色卡片（SolidCard，表单场景）；纯展示型组件——草稿、选中类型、
/// 焦点与保存回调全部由外部传入，保存成功的轻量反馈（toast）由外部负责。
public struct QuickCaptureCard: View {
    @Binding public var draft: String
    @Binding public var category: FlashCore.Category
    /// 可选的外部焦点绑定（如 Home 的 ⌘N 聚焦）；nil 表示不接管焦点
    public let focus: FocusState<Bool>.Binding?
    public let onSave: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(draft: Binding<String>,
         category: Binding<FlashCore.Category>,
         focus: FocusState<Bool>.Binding? = nil,
         onSave: @escaping () -> Void) {
        self._draft = draft
        self._category = category
        self.focus = focus
        self.onSave = onSave
    }

    private var hasDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    SegmentedPicker(selection: $category, options: [
                        .init(value: Category.log, title: "日志"),
                        .init(value: Category.idea, title: "灵感"),
                    ])
                    .frame(maxWidth: 220) // 分段控件固有宽度（几何值）
                    // 四模块色：分段选中色跟随类别（日志紫 / 灵感黄）
                    .tint(category == .idea ? BrandColors.ideaYellow : BrandColors.logPurple)
                    .animation(Motion.quick(reduceMotion), value: category)
                    Spacer()
                }

                TextField("写下刚刚闪过的念头……", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .modifier(OptionalFocusModifier(focus: focus))

                HStack {
                    Spacer()
                    Button("保存", action: onSave)
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColors.brandPrimary)
                        .disabled(!hasDraft)
                        .keyboardShortcut(.return, modifiers: .command)
                        .animation(Motion.quick(reduceMotion), value: hasDraft)
                }
            }
            .padding(Spacing.md)
        }
        .cardFloat(reduceMotion: reduceMotion)
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
        @State var category: Category = .log
        var body: some View {
            QuickCaptureCard(draft: $draft, category: $category) {}
                .padding(Spacing.lg)
                .frame(width: 480)
                .background(BrandColors.pageBackground)
        }
    }
    return PreviewHost()
}
