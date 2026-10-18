// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore
import FlashDesign

/// 新建/编辑记录 sheet：FormSection 分组——「正文与类型」（内容编辑器 + 日志/灵感分段）、
/// 「标签、重要度、日期」（标签分段 + 重要度 Stepper + 收藏开关 + 记录日期 DatePicker）。
/// 编辑既有灵感时左下角提供「转为任务」（onConvertToTask，PRD §18）。
/// 保存无效时说明原因：正文为空禁用保存；超出契约上限禁用保存并显示计数。
struct LogEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let log: LogItem
    /// 标题（新建场景传「新建记录」/「新建灵感」，默认保持编辑语义）
    let title: String
    let onSave: (LogItem) async throws -> Void
    /// Idea→Task 转化入口（PRD §18）：仅编辑既有灵感时由父视图传入；
    /// 新建草稿尚未入库（sourceLogId 会悬空），不显示该入口
    var onConvertToTask: ((LogItem) -> Void)? = nil

    @State private var content: String
    @State private var category: Category
    @State private var colorTag: ColorTag
    @State private var importance: Int
    @State private var isFavorite: Bool
    @State private var recordDate: Date
    /// 分区入场 stagger 开关
    @State private var appeared = false
    /// 保存成功后的勾选反馈（闪现后自动关闭，不阻塞）
    @State private var saved = false
    @State private var showDiscard = false
    /// 保存中的加载态与错误提示
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @FocusState private var contentFocused: Bool

    init(log: LogItem, title: String = "编辑记录",
         onSave: @escaping (LogItem) async throws -> Void,
         onConvertToTask: ((LogItem) -> Void)? = nil) {
        self.log = log
        self.title = title
        self.onSave = onSave
        self.onConvertToTask = onConvertToTask
        _content = State(initialValue: log.content)
        _category = State(initialValue: log.category)
        _colorTag = State(initialValue: log.colorTag)
        _importance = State(initialValue: log.importance)
        _isFavorite = State(initialValue: log.isFavorite ?? false)
        _recordDate = State(initialValue: DateFormatting.parseDay(log.recordDate) ?? Date())
    }

    /// 契约上限（UTF-16 单元）：超限禁用保存并显示计数，不静默截断
    private var contentExceedsLimit: Bool { !TextLimits.fits(content) }

    private var dirty: Bool {
        content != log.content || category != log.category || colorTag != log.colorTag ||
        importance != log.importance || isFavorite != (log.isFavorite ?? false) ||
        DateFormatting.dayString(recordDate) != log.recordDate
    }

    private func close() {
        guard !isSaving && !saved else { return }
        if dirty { showDiscard = true } else { dismiss() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title).font(Typography.cardTitle)
                    .foregroundStyle(BrandColors.textPrimary)
                    .staggeredIn(index: 0, appeared: appeared, reduceMotion: reduceMotion)

                FormSection("正文与类型") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SegmentedPicker(selection: $category, options: [
                            .init(value: Category.log, title: "日志"),
                            .init(value: Category.idea, title: "灵感"),
                        ])
                        .frame(maxWidth: 220) // 分段控件固有宽度（几何值）
                        // 四模块色：分段选中色跟随类别（日志紫 / 灵感黄）
                        .tint(category == .idea ? BrandColors.ideaYellow : BrandColors.logPurple)
                        .animation(Motion.quick(reduceMotion), value: category)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $content)
                                .font(Typography.body)
                                .frame(minHeight: 120) // 正文编辑区最小高度（几何值）
                                .padding(Spacing.xxs)
                                .scrollContentBackground(.hidden)
                                .background(BrandColors.weakSurface)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Radius.field)
                                        .stroke(BrandColors.weakBorder, lineWidth: 1)
                                }
                                .focused($contentFocused)
                            if content.isEmpty {
                                Text("记录内容…")
                                    .font(Typography.body)
                                    .foregroundStyle(BrandColors.textSecondary)
                                    .padding(.horizontal, Spacing.xs)
                                    .padding(.vertical, Spacing.xs)
                                    .allowsHitTesting(false)
                            }
                        }

                        if contentExceedsLimit {
                            Text("已超出上限（\(content.utf16.count)/\(TextLimits.maxContentUTF16)），请删减后再保存")
                                .font(Typography.caption)
                                .foregroundStyle(Color(nsColor: .systemRed))
                        }
                    }
                    .padding(Spacing.md)
                }
                .staggeredIn(index: 1, appeared: appeared, reduceMotion: reduceMotion)

                FormSection("标签、重要度、日期") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Picker("标签", selection: $colorTag) {
                            ForEach(ColorTag.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        HStack {
                            Stepper("重要度：\(importance)", value: $importance, in: 0...4)
                            Spacer()
                            DatePicker("记录日期", selection: $recordDate, displayedComponents: .date)
                                .labelsHidden()
                        }

                        Toggle("收藏", isOn: $isFavorite)
                            .toggleStyle(.checkbox)
                    }
                    .padding(Spacing.md)
                }
                .staggeredIn(index: 2, appeared: appeared, reduceMotion: reduceMotion)

                HStack {
                    if !saved, category == .idea, onConvertToTask != nil {
                        Button("转为任务") { convertToTask() }
                            .disabled(isSaving
                                      || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help("打开任务编辑器并预填灵感内容，原灵感保留")
                    }
                    Spacer()
                    if saved {
                        // 保存成功：Motion.bounce 勾选反馈（0.45s 后自动关闭）
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(BrandColors.accent)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Button("取消") { close() }
                            .disabled(isSaving)
                            .keyboardShortcut(.cancelAction)
                        Button(isSaving ? "保存中…" : "保存") { save() }
                            .buttonStyle(.borderedProminent)
                            .tint(BrandColors.brandPrimary)
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || contentExceedsLimit || isSaving)
                            .help(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? "正文为空，无法保存" : "")
                    }
                }
                .staggeredIn(index: 3, appeared: appeared, reduceMotion: reduceMotion)
            }
            .padding(Spacing.lg)
        }
        .disabled(isSaving || saved)
        .interactiveDismissDisabled(dirty || isSaving || saved)
        .confirmationDialog("放弃未保存的修改？", isPresented: $showDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        }
        .frame(width: 480) // 编辑面板固有宽度（几何值）
        .background(BrandColors.pageBackground)
        .onAppear {
            appeared = true
            contentFocused = true
        }
        .alert("提示", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Idea→Task：把当前草稿（含未保存修改）抛给父视图打开任务编辑器，随后关闭本 sheet；
    /// 原灵感不入库修改（保留原样），草稿内容只作为任务标题预填
    private func convertToTask() {
        guard let onConvertToTask, !isSaving, !saved else { return }
        var draft = log
        draft.content = content
        draft.category = category
        draft.colorTag = colorTag
        draft.importance = importance
        draft.isFavorite = isFavorite
        draft.recordDate = DateFormatting.dayString(recordDate)
        onConvertToTask(draft)
        dismiss()
    }

    private func save() {
        guard !isSaving && !saved && !contentExceedsLimit && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSaving = true
        var updated = log
        updated.content = content
        updated.category = category
        updated.colorTag = colorTag
        // 「!!」语法只在创建时解析（importanceFromContent）；编辑正文不重解析，
        // 重要性以 Stepper 的显式值为准，避免覆盖用户手动调整
        updated.importance = importance
        updated.isFavorite = isFavorite
        updated.recordDate = DateFormatting.dayString(recordDate)
        Task {
            do {
                try await onSave(updated)
                await MainActor.run {
                    isSaving = false
                    saved = true
                    Motion.animate(Motion.bounce(), reduceMotion: reduceMotion) {}
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    self.errorMessage = "保存失败，请重试"
                }
            }
        }
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
