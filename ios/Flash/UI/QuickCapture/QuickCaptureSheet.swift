// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 快速记录面板（iOS 版 Quick Capture，规则对齐 macOS PRD §13–14）：
/// - 「✦ Flash / 现在想记录什么？」+ 自动增高输入（1–5 行），默认类型为灵感，可点选切到日志，不强制分类；
/// - 回车或「保存」提交（粘贴的多行文本保留换行），保存后立即关闭（成功触感）；
/// - 面板高度随内容测量（大字号不截断），接近字数上限时显示剩余字数；
/// - 未提交关闭（下滑 / 点外部 / 取消）保留草稿，下次打开恢复正文与类型（QuickCaptureDraftStore，与 macOS 同语义）；
/// - 保存规则（去空白 / 契约上限 / 标签与重要度）走共享 QuickCaptureCommit。
struct QuickCaptureSheet: View {
    /// 外部指定的初始类型（深链 / 快捷指令 / 控制中心）；nil 时取草稿类型或默认灵感
    let initialCategory: Category?

    @Environment(\.flashRepository) private var repository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = ""
    @State private var category: Category = .idea
    @State private var errorMessage: String? = nil
    @State private var committed = false
    @State private var saveCount = 0
    /// 内容实测高度：驱动自适应 detent（0 = 尚未测量，先用 .medium）
    @State private var contentHeight: CGFloat = 0
    @FocusState private var focused: Bool

    private let draftStore = QuickCaptureDraftStore()

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("✦ Flash")
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(BrandColors.brandPrimary)
                    Text("现在想记录什么？")
                        .font(Typography.sectionTitle)
                }
                Spacer()
                SegmentedPicker(selection: $category, options: [
                    .init(value: Category.idea, title: "灵感"),
                    .init(value: Category.log, title: "日志"),
                ])
                .frame(maxWidth: 150) // 分段控件固有宽度（几何值）
                .tint(category == .idea ? BrandColors.ideaYellow : BrandColors.logPurple)
                .animation(Motion.quick(reduceMotion), value: category)
            }

            TextField("写下刚刚闪过的念头……", text: $text, axis: .vertical)
                .font(Typography.body)
                .lineLimit(1...5)
                .focused($focused)
                .submitLabel(.done)
                .onChange(of: text) { old, new in submitOnTypedReturn(old: old, new: new) }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
                .background(BrandColors.weakSurface, in: RoundedRectangle(cornerRadius: Radius.field))

            if let remaining = remainingHint {
                Text(remaining)
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(remaining.hasPrefix("超出") ? BrandColors.destructive : BrandColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.appear(reduceMotion: reduceMotion))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.caption)
                    .foregroundStyle(BrandColors.destructive)
                    .transition(.appear(reduceMotion: reduceMotion))
            }

            HStack {
                Button("取消") { dismiss() }
                    .flashGlassButtonStyle()
                Spacer()
                Button(action: commit) {
                    Label("保存", systemImage: "arrow.up")
                        .font(Typography.body.weight(.semibold))
                }
                .flashGlassProminentButtonStyle(tint: BrandColors.brandPrimary)
                .disabled(!hasText)
                .animation(Motion.quick(reduceMotion), value: hasText)
            }
        }
        .padding(Spacing.lg)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents(contentHeight > 0 ? [.height(contentHeight), .large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: saveCount)
        .sensoryFeedback(.selection, trigger: category)
        .animation(Motion.soft(reduceMotion), value: errorMessage)
        .animation(Motion.soft(reduceMotion), value: remainingHint == nil)
        .onAppear(perform: restoreDraft)
        .onDisappear(perform: keepDraftIfNeeded)
    }

    /// 只剩不到 10% 时提示剩余字数；超出时提示超出量（与 QuickCaptureCommit 同一 UTF-16 口径）
    private var remainingHint: String? {
        let limit = TextLimits.maxContentUTF16
        let remaining = limit - text.utf16.count
        if remaining < 0 { return "超出 \(-remaining) 字" }
        return remaining < limit / 10 ? "还可输入 \(remaining) 字" : nil
    }

    /// 多行输入下回车会插入换行：只在「末尾敲入单个换行」时视为提交，粘贴的多行文本不受影响
    private func submitOnTypedReturn(old: String, new: String) {
        guard new.count == old.count + 1, new.hasSuffix("\n"), new.dropLast() == Substring(old) else { return }
        text = old
        commit()
    }

    // MARK: - 草稿

    private func restoreDraft() {
        if let draft = draftStore.load() {
            text = draft.text
            category = draft.category
        }
        if let initialCategory { category = initialCategory }
        focused = true
    }

    /// 未提交关闭：保留草稿（空正文则清除，不留空草稿）
    private func keepDraftIfNeeded() {
        guard !committed else { return }
        if hasText {
            draftStore.save(QuickCaptureDraft(text: text, category: category))
        } else {
            draftStore.clear()
        }
    }

    // MARK: - 提交

    private func commit() {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        do {
            switch try QuickCaptureCommit.commit(text, as: category, repository: repository) {
            case .saved:
                committed = true
                draftStore.clear()
                saveCount += 1
                dismiss()
            case .empty:
                return
            case .tooLong(let message):
                errorMessage = message
            }
        } catch {
            FlashLog.failure("quick_capture_save_failed", error)
            errorMessage = "保存失败，请重试"
        }
    }
}
