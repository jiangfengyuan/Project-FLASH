// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 此刻页（iOS 首个端到端切片）：问候区 → 今日一览 → 快速捕捉 → 最近闪念。
/// 读路径与 macOS 相同：@Query 直读 + 仓储写代际（revision）驱动 HomeViewModel 同步；
/// 写路径统一经 FlashRepository（保存规则走共享 QuickCaptureCommit）。
struct HomeView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState
    @Environment(IdeaReminderCenter.self) private var ideaReminders
    @Environment(FocusRouter.self) private var focusRouter
    @Environment(\.flashMarkIdeaViewed) private var markIdeaViewed
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    @State private var viewModel = HomeViewModel()
    @State private var draft = ""
    @State private var captureCategory: Category = .log
    @FocusState private var inputFocused: Bool
    @State private var errorMessage: String? = nil
    @State private var deletingLog: LogItem? = nil
    /// 最近闪念点按编辑
    @State private var editingLog: LogItem? = nil
    /// 「+ 新建 → 任务」与「灵感转任务」的任务编辑器
    @State private var showingTaskEditor = false
    @State private var ideaTaskDraft: IdeaTaskDraft? = nil
    /// 顶部 toast 文案（nil 表示不展示）；toastID 用于相同文案连发时重置计时
    @State private var toastMessage: String? = nil
    @State private var toastID = 0
    /// 可用宽度（随折叠/展开、窗口缩放实时更新）。不读屏幕尺寸、方向或机型：
    /// iPhone Duo 内屏、iPhone 镜像等场景下窗口尺寸会在运行中变化
    @State private var availableWidth: CGFloat = 0

    /// 宽于此值时改为双栏（左：今日一览 + 快速捕捉；右：最近闪念）。
    /// iPhone 竖屏约 400pt 为单栏；iPhone Duo 展开横置约 880pt（扣除竖向标签栏）为双栏
    private static let twoColumnMinWidth: CGFloat = 700

    private var isTwoColumn: Bool { availableWidth >= Self.twoColumnMinWidth }

    private var openTaskCount: Int {
        taskEntities.filter { $0.completedAt == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GreetingHeaderView(
                    onNewLog: { startCapture(.log) },
                    onNewIdea: { startCapture(.idea) },
                    onNewEmotion: { appState.push(.emotion) },
                    onNewTask: { showingTaskEditor = true }
                )

                if ideaReminders.shouldRemind {
                    ideaReminderRow
                        .transition(.appear(reduceMotion: reduceMotion))
                }

                if isTwoColumn {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            overviewCard
                            captureCard
                        }
                        .frame(maxWidth: .infinity)
                        recentSection
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    overviewCard
                    captureCard
                    recentSection
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
            // 与 macOS 此刻页同一上限：超宽窗口不把卡片拉成细长条
            .frame(maxWidth: Metrics.toolMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BrandColors.pageBackground)
        // 问候区即页标题：导航栏只承载全局搜索按钮
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { GlobalSearchToolbarItem() }
        .onAppear { syncViewModel() }
        // 写代际变化 = 任一表有提交；不直接观察实体数组（PersistentModel 相等走身份，漏掉就地更新）
        .onChange(of: repository?.revision ?? 0) { syncViewModel() }
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, Spacing.sm)
            }
        }
        .animation(reduceMotion ? Motion.reducedFade(true) : Motion.spring(), value: toastMessage != nil)
        .task(id: toastID) {
            guard toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log,
                         title: log.category == .idea ? "编辑灵感" : "编辑记录",
                         onSave: { updated in
                             guard let repository else { throw SaveError() }
                             try repository.updateLog(updated)
                         },
                         onConvertToTask: { draft in
                             ideaTaskDraft = IdeaTaskDraft(sourceLogId: draft.id, title: draft.content)
                         })
        }
        .sheet(isPresented: $showingTaskEditor) {
            TaskEditorView(selectedDate: Date(), task: nil) { task in
                if saveTask(task) { showingTaskEditor = false }
            }
        }
        .sheet(item: $ideaTaskDraft) { draft in
            TaskEditorView(selectedDate: Date(), task: nil, ideaDraft: draft) { task in
                if saveTask(task) { ideaTaskDraft = nil }
            }
        }
        .alert(deleteTitle, isPresented: deletePresented) {
            Button("删除", role: .destructive) { deleteConfirmed() }
            Button("取消", role: .cancel) {}
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// 灵感提醒提示行（PRD v3 §6.3，对齐 Android）：未读灵感 ≥ 3 时出现，
    /// 点按打开最早的一条未读灵感（经 FocusRouter 跳到记录页编辑弹层，打开即已读）
    private var ideaReminderRow: some View {
        Button {
            if let oldest = ideaReminders.oldestUnread {
                focusRouter.request(.log(oldest.id))
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lightbulb.max")
                    .scaledSystemFont(size: 18, weight: .medium, relativeTo: .body)
                    .foregroundStyle(BrandColors.ideaYellowText)
                    .frame(width: 36, height: 36) // 图标底尺寸（几何值）
                    .background(BrandColors.ideaYellow.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) { // 2：标题与副标题的紧凑节奏
                    Text("想法等待梳理")
                        .font(Typography.cardTitle)
                        .foregroundStyle(BrandColors.textPrimary)
                    Text("你还有 \(ideaReminders.unreadCount) 个想法，先看看最早的一条")
                        .font(Typography.caption)
                        .foregroundStyle(BrandColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.xs)
                Text("\(ideaReminders.unreadCount)")
                    .font(Typography.cardTitle.monospacedDigit())
                    .foregroundStyle(BrandColors.ideaYellowText)
                    .contentTransition(.numericText())
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .background(BrandColors.cardSurface, in: RoundedRectangle(cornerRadius: Radius.cardSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.cardSmall)
                    .stroke(BrandColors.weakBorder, lineWidth: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ideaReminders.unreadCount) 个想法等待梳理，打开最早的一条")
        .animation(Motion.soft(reduceMotion), value: ideaReminders.unreadCount)
    }

    private func openEditor(_ log: LogItem) {
        if log.category == .idea { markIdeaViewed?(log.id) }
        editingLog = log
    }

    private var overviewCard: some View {
        HomeTodayOverviewCard(
            recordCount: viewModel.todayRecordCount,
            openTaskCount: openTaskCount,
            emotionEmoji: viewModel.emotionSnapshot.emoji,
            emotionTitle: viewModel.emotionSnapshot.title
        )
    }

    private var captureCard: some View {
        QuickCaptureCard(draft: $draft, category: $captureCategory,
                         focus: $inputFocused) {
            quickAdd()
        }
    }

    // MARK: - 最近闪念

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
                    .font(Typography.secondary)
                    .foregroundStyle(BrandColors.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                // 无悬停：卡片内操作按钮不出现；点按编辑，收藏 / 删除走长按菜单
                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.recentLogs) { log in
                        LogCardView(log: log, actionsVisibility: .hidden,
                                    isUnread: ideaReminders.unreadIDs.contains(log.id))
                            .contentShape(Rectangle())
                            .onTapGesture { openEditor(log) }
                            .accessibilityAddTraits(.isButton)
                            .contextMenu {
                                Button("编辑", systemImage: "pencil") { openEditor(log) }
                                Button(log.isFavorite == true ? "取消收藏" : "收藏",
                                       systemImage: log.isFavorite == true ? "star.slash" : "star") {
                                    toggleFavorite(log)
                                }
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    deletingLog = log
                                }
                            }
                    }
                }
            }
            .animation(Motion.soft(reduceMotion), value: viewModel.recentLogs)
        }
    }

    // MARK: - 数据注入 / 保存

    /// 实体→模型映射只在写代际变化时发生，VM 内部按值比较，内容未变直接返回
    private func syncViewModel() {
        viewModel.update(logs: logEntities.map { $0.toModel() },
                         emotions: emotionEntities.map { $0.toModel() })
    }

    private func startCapture(_ category: Category) {
        captureCategory = category
        inputFocused = true
    }

    private func quickAdd() {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        do {
            switch try QuickCaptureCommit.commit(draft, as: captureCategory, repository: repository) {
            case .saved(let toast):
                draft = ""
                showToast(toast)
            case .empty:
                return
            case .tooLong(let message):
                errorMessage = message
            }
        } catch {
            // 弹窗文案固定，详细错误只进控制台
            print("HomeView: 快速记录保存失败 - \(error)")
            errorMessage = "保存失败，请重试"
        }
    }

    private func toggleFavorite(_ log: LogItem) {
        do { try repository?.setLogFavorite(id: log.id, !(log.isFavorite ?? false)) }
        catch {
            print("HomeView: 收藏切换失败 - \(error)")
            errorMessage = "操作失败，请重试"
        }
    }

    private func deleteConfirmed() {
        guard let log = deletingLog else { return }
        do { try repository?.deleteLog(id: log.id) }
        catch {
            print("HomeView: 删除记录失败 - \(error)")
            errorMessage = "删除失败，请重试"
        }
    }

    private struct SaveError: Error {}

    /// 任务入库 + 异步安排系统提醒（TaskSaving 与记录页、日历页同一契约）
    @discardableResult
    private func saveTask(_ task: TaskItem) -> Bool {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return false }
        do {
            try repository.saveTask(task)
            showToast("✓ 已保存任务")
            Task {
                if let warning = await TaskSaving.scheduleReminder(for: task) { errorMessage = warning }
            }
            return true
        } catch {
            print("HomeView: 任务保存失败 - \(error)")
            errorMessage = "任务保存失败，请重试"
            return false
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastID += 1
    }

    private var deleteTitle: String {
        deletingLog?.category == .idea ? "删除这条灵感？" : "删除这条记录？"
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingLog != nil }, set: { if !$0 { deletingLog = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
