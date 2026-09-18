// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

/// 此刻页（核心记录闭环）：问候区 + 「+ 新建」→ 今日一览卡（记录数/待办数/情绪状态）
/// → 快速捕捉卡（日志/灵感分段，保存后 toast 反馈并立即刷新一览）→ 最近闪念（全宽记录卡，
/// 宽窗口两列、阅读优先）→ 空状态（EmptyStateView，行动按钮聚焦输入框）。
/// 数据装配由 HomeViewModel 完成，仅在注入的 logs/emotions 变化时重算；
/// ⌘N 聚焦快速记录输入框（⌘K 全局搜索走「记录」页）；情绪/任务经「+ 新建」直达。
struct HomeView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    /// 数据装配层：onAppear / onChange 时注入最新 logs/emotions，内部缓存派生数据
    @State private var viewModel = HomeViewModel()
    @State private var draft = ""
    @State private var captureCategory: Category = .log
    @FocusState private var inputFocused: Bool
    @State private var errorMessage: String? = nil
    /// 「+ 新建」记录/灵感 sheet 的草稿（nil 表示不展示）
    @State private var newLogDraft: LogItem? = nil
    /// 「+ 新建」任务：直达任务编辑器
    @State private var showingTaskEditor = false
    /// 记录卡的编辑/删除目标
    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    /// 顶部 toast 文案（nil 表示不展示）；toastID 用于相同文案连发时重置计时
    @State private var toastMessage: String? = nil
    @State private var toastID = 0
    /// 入场动画标记（问候区 / 今日一览 / 主体，按 Motion.staggerDelay 依次入场）
    @State private var headerAppeared = false
    @State private var overviewAppeared = false
    @State private var bodyAppeared = false

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }
    /// 未完成待办数（不限今日）
    private var openTaskCount: Int { taskEntities.filter { $0.completedAt == nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GreetingHeaderView(
                    onNewLog: { presentNewLog(category: .log) },
                    onNewIdea: { presentNewLog(category: .idea) },
                    onNewEmotion: { appState.selectedModule = .emotion },
                    onNewTask: { showingTaskEditor = true }
                )
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: !headerAppeared && !reduceMotion ? 6 : 0)

                HomeTodayOverviewCard(
                    recordCount: viewModel.todayRecordCount,
                    openTaskCount: openTaskCount,
                    emotionEmoji: viewModel.emotionSnapshot.emoji,
                    emotionTitle: viewModel.emotionSnapshot.title
                )
                .opacity(overviewAppeared ? 1 : 0)
                .offset(y: !overviewAppeared && !reduceMotion ? 6 : 0)

                QuickCaptureCard(draft: $draft, category: $captureCategory,
                                 focus: $inputFocused) {
                    quickAdd(as: captureCategory)
                }
                .onAppear { flushNewLogRequest() }
                .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }

                recentSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: Metrics.toolMaxWidth)
            .frame(maxWidth: .infinity)
            .opacity(bodyAppeared ? 1 : 0)
            .offset(y: !bodyAppeared && !reduceMotion ? 6 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.pageBackground)
        .onAppear {
            syncViewModel()
            playEntranceAnimation()
        }
        .onChange(of: logs) { syncViewModel() }
        .onChange(of: emotions) { syncViewModel() }
        // 顶部 toast：过渡由 ToastView 内置 .pop 接管，调用点不再叠加 .transition
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, 12)
            }
        }
        .animation(toastAnimation, value: toastMessage != nil)
        .task(id: toastID) {
            guard toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
        .sheet(item: $newLogDraft) { draftItem in
            LogEditSheet(log: draftItem,
                         title: draftItem.category == .idea ? "新建灵感" : "新建记录") { updated in
                try saveNewLog(updated)
            }
        }
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log,
                         title: log.category == .idea ? "编辑灵感" : "编辑记录") { updated in
                guard let repository else { throw SaveError() }
                try repository.updateLog(updated)
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            TaskEditorView(selectedDate: Date(), task: nil) { task in
                saveTask(task)
            }
        }
        .alert(deleteTitle, isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let log = deletingLog {
                    do { try repository?.deleteLog(id: log.id) }
                    catch {
                        print("HomeView: 删除记录失败 - \(error)")
                        errorMessage = "删除失败，请重试"
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 最近闪念

    /// 「最近闪念」：全宽记录卡，宽窗口两列（ViewThatFits 横向放不下两列时退回单列，
    /// 阅读优先）；空态用 EmptyStateView，行动按钮聚焦快速捕捉输入框。
    @ViewBuilder
    private var recentSection: some View {
        if viewModel.recentLogs.isEmpty {
            EmptyStateView(
                systemImage: "sparkles",
                title: "今天还没有记录。",
                actionTitle: "记下第一个念头"
            ) {
                inputFocused = true
            }
            .frame(minHeight: 220)
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("最近闪念")
                    .font(.callout)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        logColumn(logs: Array(viewModel.recentLogs.prefix(3)))
                        logColumn(logs: Array(viewModel.recentLogs.dropFirst(3).prefix(3)))
                    }
                    logColumn(logs: viewModel.recentLogs)
                }
            }
            .animation(listContentAnimation, value: viewModel.recentLogs)
        }
    }

    private func logColumn(logs: [LogItem]) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(logs) { log in
                LogCardView(log: log,
                            onEdit: { editingLog = log },
                            onDelete: { deletingLog = log })
                    .contextMenu {
                        Button("编辑…") { editingLog = log }
                        Button("删除", role: .destructive) { deletingLog = log }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 动画

    /// toast 动效：Motion.spring 轻弹簧；减弱动态时退化为 reducedFade 极短淡变
    private var toastAnimation: Animation? {
        reduceMotion ? Motion.reducedFade(true) : Motion.spring()
    }

    /// 列表内容变化过渡（走 Motion.soft；减弱动态时直接替换，不做过渡）
    private var listContentAnimation: Animation? {
        Motion.soft(reduceMotion)
    }

    /// 入场动画：三区块 fade + 轻微上移（y 6→0），按 staggerDelay 依次入场；
    /// 减弱动态时 Motion.softOut 返回 nil，只留瞬时呈现
    private func playEntranceAnimation() {
        guard !headerAppeared else { return }
        withAnimation(Motion.softOut(reduceMotion)) { headerAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(1))) { overviewAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(2))) { bodyAppeared = true }
    }

    // MARK: - 数据注入 / ⌘N / 新建 / 保存

    /// 把最新 logs/emotions 注入 ViewModel；内容未变时 VM 内部直接返回，不重算
    private func syncViewModel() {
        viewModel.update(logs: logs, emotions: emotions)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var deleteTitle: String {
        deletingLog?.category == .idea ? "删除这条灵感？" : "删除这条记录？"
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingLog != nil }, set: { if !$0 { deletingLog = nil } })
    }

    /// 菜单「新建记录」⌘N：token 递增时聚焦输入框。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushNewLogRequest() {
        guard appState.newLogRequestToken != appState.handledNewLogToken else { return }
        appState.markNewLogHandled()
        inputFocused = true
    }

    /// 「+ 新建」菜单：构造空白 LogItem 预填 category/colorTag，弹 LogEditSheet 真新建
    private func presentNewLog(category: Category) {
        newLogDraft = LogItem(
            id: UUID().uuidString,
            content: "",
            colorTag: category == .idea ? .idea : .daily,
            category: category,
            importance: 0,
            createdAt: DateFormatting.isoNow(),
            recordDate: DateFormatting.today())
    }

    private struct SaveError: Error {}

    /// LogEditSheet 保存回调：作为新记录入库（id/时间由仓库重新生成，记录日期透传用户选择）
    private func saveNewLog(_ item: LogItem) throws {
        guard let repository else { throw SaveError() }
        try repository.addLog(content: item.content, colorTag: item.colorTag,
                              category: item.category, importance: item.importance,
                              recordDate: DateFormatting.parseDay(item.recordDate))
        showToast(item.category == .idea ? "✓ 已保存到灵感" : "✓ 已保存到日志")
    }

    /// 「+ 新建」任务直达编辑器后的保存：入库 + 重建系统提醒（与日历页同一契约）
    private func saveTask(_ task: TaskItem) {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        do {
            try repository.saveTask(task)
            showingTaskEditor = false
            showToast("✓ 已保存任务")
            Task {
                do {
                    try await TaskReminderScheduler.shared.schedule(task)
                    if TaskReminderScheduler.hasPastReminder(task) {
                        errorMessage = "任务已保存，但提醒时间已过，将不会提醒"
                    }
                } catch {
                    errorMessage = "任务已保存，但系统提醒未启用"
                }
            }
        } catch {
            print("HomeView: 任务保存失败 - \(error)")
            errorMessage = "任务保存失败，请重试"
        }
    }

    /// 展示顶部 toast；toastID 递增使相同文案连发也重新计时（.task(id:) 自动取消旧计时）
    private func showToast(_ message: String) {
        toastMessage = message
        toastID += 1
    }

    private func quickAdd(as category: Category) {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        // 契约上限（UTF-16 单元）：超限不静默截断，保留草稿并弹提示说明原因
        guard TextLimits.fits(content) else {
            errorMessage = "内容超出 \(TextLimits.maxContentUTF16) 字上限，请删减后再保存"
            return
        }
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        do {
            switch category {
            case .log:
                try repository.addLog(content: content, colorTag: .daily, category: .log)
            case .idea:
                try repository.addLog(content: content, colorTag: .idea, category: .idea,
                                      importance: importanceFromContent(content))
            }
            draft = ""
            showToast(category == .idea ? "✓ 已保存到灵感" : "✓ 已保存到日志")
        } catch {
            // 弹窗文案固定，详细错误只进控制台（localizedDescription 可能含本机路径）
            print("HomeView: 快速记录保存失败 - \(error)")
            errorMessage = "保存失败，请重试"
        }
    }
}
