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
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    @State private var viewModel = HomeViewModel()
    @State private var draft = ""
    @State private var captureCategory: Category = .log
    @FocusState private var inputFocused: Bool
    @State private var errorMessage: String? = nil
    @State private var deletingLog: LogItem? = nil
    /// 顶部 toast 文案（nil 表示不展示）；toastID 用于相同文案连发时重置计时
    @State private var toastMessage: String? = nil
    @State private var toastID = 0

    private var openTaskCount: Int {
        taskEntities.filter { $0.completedAt == nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GreetingHeaderView(
                    onNewLog: { startCapture(.log) },
                    onNewIdea: { startCapture(.idea) },
                    // 情绪 / 任务模块尚未移植（M3 / M4）：先给出明确提示，不跳空页
                    onNewEmotion: { showToast("情绪记录即将在 iOS 上线") },
                    onNewTask: { showToast("任务即将在 iOS 上线") }
                )

                HomeTodayOverviewCard(
                    recordCount: viewModel.todayRecordCount,
                    openTaskCount: openTaskCount,
                    emotionEmoji: viewModel.emotionSnapshot.emoji,
                    emotionTitle: viewModel.emotionSnapshot.title
                )

                QuickCaptureCard(draft: $draft, category: $captureCategory,
                                 focus: $inputFocused) {
                    quickAdd()
                }

                recentSection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BrandColors.pageBackground)
        .toolbar(.hidden, for: .navigationBar)
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
                // iPhone 单列；无悬停，卡片内操作按钮不出现，收藏 / 删除走长按菜单
                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.recentLogs) { log in
                        LogCardView(log: log)
                            .contextMenu {
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
