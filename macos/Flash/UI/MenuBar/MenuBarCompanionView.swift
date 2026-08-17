// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

/// 菜单栏伴侣面板（PRD §26 Menu Bar Companion，输入交互遵循 §13/§14 Quick Capture）：
/// 快速记录（回车即存，默认类型 Idea）+ 今日概览（只读）+ 快速跳转 + 退出。
/// MenuBarExtra(.window) 由系统负责点击外部关闭；Esc 通过隐藏快捷键按钮关闭。
/// 草稿保留在面板生命周期内，重开面板不丢内容（§14 自动保存草稿原则）。
struct MenuBarCompanionView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = ""
    /// 成功/失败反馈文案；非 nil 时在标题行右侧显示
    @State private var feedback: String? = nil
    @State private var feedbackIsError = false
    /// 反馈自动消隐令牌：连续保存时只认最后一次的计时
    @State private var feedbackToken = 0
    /// 面板跨天重开时刷新「今日」谓词（@Query 谓词初始化后不更新，靠 .id 重建）
    @State private var today = DateFormatting.today()
    @FocusState private var inputFocused: Bool

    private static let panelWidth: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            captureInput
            Divider()
            TodaySummary(today: today)
                .id(today)
            Divider()
            quickJumps
            Divider()
            footer
        }
        .padding(14)
        .frame(width: Self.panelWidth)
        .background { escCloser }
        .onAppear {
            today = DateFormatting.today()
            // 面板重开时窗口尚未成为 key，直接置焦点不生效，延后一拍
            DispatchQueue.main.async { inputFocused = true }
        }
    }

    // MARK: - 区块

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(BrandColors.accent)
            Text("Flash")
                .font(.headline)
            Spacer()
            if let feedback {
                Label(feedback,
                      systemImage: feedbackIsError ? "exclamationmark.triangle" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(feedbackIsError ? Color(nsColor: .systemRed) : BrandColors.accent)
                    .transition(.pop(reduceMotion: reduceMotion))
            }
        }
    }

    private var captureInput: some View {
        TextField("今天想记录什么？", text: $draft)
            .textFieldStyle(.plain)
            .font(.body)
            .focused($inputFocused)
            .onSubmit(save)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5)
            }
    }

    private var quickJumps: some View {
        HStack(spacing: 8) {
            JumpButton(title: "记录", systemImage: Module.logflow.systemImage,
                       reduceMotion: reduceMotion) { openMainWindow(.logflow) }
            JumpButton(title: "情绪", systemImage: Module.emotion.systemImage,
                       reduceMotion: reduceMotion) { openMainWindow(.emotion) }
            JumpButton(title: "日历", systemImage: Module.calendar.systemImage,
                       reduceMotion: reduceMotion) { openMainWindow(.calendar) }
        }
    }

    private var footer: some View {
        HStack {
            Button { openMainWindow() } label: {
                Label("打开 Flash", systemImage: "macwindow")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            Spacer()
            Button("退出") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Esc 关闭面板：隐藏按钮挂快捷键，保持在视图层级内即可响应
    private var escCloser: some View {
        Button("关闭面板") { closePanel() }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden()
            .accessibilityHidden(true)
    }

    // MARK: - 动作

    private func save() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard let repository else { showFeedback("存储未就绪", isError: true); return }
        do {
            // Quick Capture 默认类型 Idea（PRD §13.3），沿用 !! 语法标记重要度
            try repository.addLog(content: content, colorTag: .idea, category: .idea,
                                  importance: importanceFromContent(content))
            draft = ""
            showFeedback("已保存", isError: false)
            inputFocused = true
        } catch {
            // 固定文案，详情仅输出到控制台，避免向用户暴露内部路径
            print("[MenuBarCompanion] 保存记录失败: \(error)")
            showFeedback("保存失败，请重试", isError: true)
        }
    }

    private func showFeedback(_ text: String, isError: Bool) {
        feedbackToken += 1
        let token = feedbackToken
        Motion.animate(Motion.softOut(), reduceMotion: reduceMotion) {
            feedback = text
            feedbackIsError = isError
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard token == feedbackToken else { return }
            Motion.animate(Motion.soft(), reduceMotion: reduceMotion) {
                feedback = nil
            }
        }
    }

    /// 打开（或唤起）主窗口并切到指定模块；nil 表示保持当前模块
    private func openMainWindow(_ module: Module? = nil) {
        if let module { appState.selectedModule = module }
        openWindow(id: "main")
        NSApp.activate()
        closePanel()
    }

    /// MenuBarExtra(.window) 面板浮于普通窗口之上（level 高于 .normal），
    /// 只在这种窗口是 key 时关闭，避免误关主窗口
    private func closePanel() {
        guard let window = NSApp.keyWindow, window.level != .normal else { return }
        window.close()
    }
}

/// 今日概览（只读）：今日记录数 + 最新一条情绪。
/// 自带 @Query，与输入框的 draft 状态隔离，每敲一键不触发全量查询重建。
private struct TodaySummary: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var todayLogs: [LogEntity]
    @Query private var todayEmotions: [EmotionEntity]

    init(today: String) {
        _todayLogs = Query(filter: #Predicate<LogEntity> { $0.recordDate == today })
        _todayEmotions = Query(filter: #Predicate<EmotionEntity> { $0.recordDate == today },
                               sort: \EmotionEntity.createdAt, order: .reverse)
    }

    private var latestLevel: EmotionLevel? {
        todayEmotions.first.flatMap { EmotionLevel(rawValue: $0.level) }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "note.text")
            Text("今日 \(todayLogs.count) 条记录")
                .monospacedDigit()
                // 数字变化滚动过渡（macOS 14+）；Reduce Motion 时瞬变
                .contentTransition(.numericText())
                .animation(Motion.quick(reduceMotion), value: todayLogs.count)
            Spacer()
            if let level = latestLevel {
                Text(level.emoji)
                Text(level.displayName)
            } else {
                Text("今天还没记录情绪")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 快速跳转小按钮：细边框 + hover 高亮，动效走 Motion.quick
private struct JumpButton: View {
    let title: String
    let systemImage: String
    let reduceMotion: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(hovering ? 1 : 0.6),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(hovering ? 0.8 : 0.4),
                                      lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .animation(Motion.quick(reduceMotion), value: hovering)
        .onHover { hovering = $0 }
    }
}

#Preview {
    MenuBarCompanionView()
        .environment(AppState())
}
