// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// Quick Capture 浮动面板内容（PRD §13.3 布局 / §14 交互原则）：
/// 标题「现在想记录什么？」+ 输入区 + 类型标签（默认 Idea，可点选，不强制）+ Cancel / Save ⌘↵。
/// Enter（单行输入）或 ⌘Enter 提交、Esc 放弃；保存后立即关闭由控制器负责。
/// 纯展示型组件：草稿恢复值由 init 注入，提交/取消/变更经闭包抛给 QuickCaptureController。
struct QuickCaptureView: View {
    /// 提交（Enter/⌘Enter/保存按钮）：返回 nil 表示已保存（控制器随即关闭面板），
    /// 非 nil 为错误文案（面板保持打开，内联展示）
    let onCommit: (String, Category) -> String?
    /// 放弃（Esc/取消按钮/失焦关闭/再次按热键）：携带当前草稿供持久化
    let onCancel: (String, Category) -> Void
    /// 草稿变化追踪（控制器在失焦关闭时持久化最新值）
    let onChange: (String, Category) -> Void

    @State private var text: String
    @State private var category: Category
    @State private var errorMessage: String? = nil
    @FocusState private var inputFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(draft: QuickCaptureDraft,
         onCommit: @escaping (String, Category) -> String?,
         onCancel: @escaping (String, Category) -> Void,
         onChange: @escaping (String, Category) -> Void) {
        _text = State(initialValue: draft.text)
        _category = State(initialValue: draft.category)
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.onChange = onChange
    }

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // ✦ Flash（对齐 PRD §13.3 头部）
            HStack(spacing: 6) { // 6：图标与标题的紧凑节奏（与菜单栏伴侣同源）
                Image(systemName: "sparkles")
                    .foregroundStyle(BrandColors.accent)
                Text("Flash")
                    .font(Typography.cardTitle)
                Spacer()
            }

            Text("现在想记录什么？")
                .font(Typography.sectionTitle)
                .foregroundStyle(BrandColors.textPrimary)

            TextField("写下刚刚闪过的念头……", text: $text)
                .textFieldStyle(.plain)
                .font(Typography.body)
                .focused($inputFocused)
                .onSubmit(commit) // Enter（单行）提交（PRD §14）
                .padding(.horizontal, 10) // 输入框横向内距（与菜单栏伴侣一致，无对应令牌）
                .padding(.vertical, Spacing.xs)
                .background(Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .strokeBorder(BrandColors.weakBorder, lineWidth: 0.5)
                }

            // 类型标签：默认 Idea，点选切换，不强制（PRD §13.3/§14）
            HStack {
                SegmentedPicker(selection: $category, options: [
                    .init(value: Category.idea, title: "灵感"),
                    .init(value: Category.log, title: "日志"),
                ])
                .frame(maxWidth: 220) // 分段控件固有宽度（与首页快速捕捉卡一致）
                .tint(category == .idea ? BrandColors.ideaYellow : BrandColors.logPurple)
                .animation(Motion.quick(reduceMotion), value: category)
                Spacer()
            }

            HStack {
                // 错误文案放按钮行（行高恒定，面板窗口固定尺寸不裁剪）；保存成功即关，无需成功反馈
                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Color(nsColor: .systemRed))
                        .lineLimit(1)
                }
                Spacer()
                Button("取消") { onCancel(text, category) }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("保存 ⌘↵") { commit() }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandColors.brandPrimary)
                    .disabled(!hasContent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .animation(Motion.quick(reduceMotion), value: hasContent)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 440) // 面板固有宽度（Spotlight 风格紧凑几何值）
        // 悬浮层玻璃（macOS 26+ Liquid Glass / 15 回退 regularMaterial + 细边框）
        .flashGlassBackground(in: RoundedRectangle(cornerRadius: Radius.glass, style: .continuous))
        .onChange(of: text) { _, _ in onChange(text, category) }
        .onChange(of: category) { _, _ in onChange(text, category) }
        .onAppear {
            // 面板 show 时窗口尚未成为 key，直接置焦点不生效，延后一拍（同菜单栏伴侣）
            DispatchQueue.main.async { inputFocused = true }
        }
    }

    private func commit() {
        errorMessage = onCommit(text, category)
    }
}

#Preview {
    QuickCaptureView(draft: QuickCaptureDraft(text: "最近想到一个新的 App 设计……", category: .idea),
                     onCommit: { _, _ in nil }, onCancel: { _, _ in }, onChange: { _, _ in })
        .padding(Spacing.xl)
}
