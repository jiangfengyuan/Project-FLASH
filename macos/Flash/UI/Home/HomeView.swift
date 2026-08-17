// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

/// 首页仪表盘：问候区 + 今日概览 + 双栏（最近动态/快速记录/本周洞察 | 情绪快照）。
/// 数据装配全部由 HomeViewModel 完成，仅在注入的 logs/emotions 变化时重算；
/// 搜索框经 200ms 防抖写入 debouncedQuery 后，「最近动态」切换为全量「搜索结果」；
/// ⌘K 聚焦搜索框、⌘N 聚焦快速记录输入框；保存成功经顶部 toast 反馈。
struct HomeView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]

    /// 数据装配层：onAppear / onChange 时注入最新 logs/emotions，内部缓存派生数据
    @State private var viewModel = HomeViewModel()
    @State private var draft = ""
    @State private var searchText = ""
    /// searchText 去空白并经 200ms 防抖后的有效查询词，驱动搜索结果与时间线切换
    @State private var debouncedQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var errorMessage: String? = nil
    @State private var handledNewLogToken = 0
    @State private var handledSearchToken = 0
    /// 「+ 新建」sheet 的草稿（nil 表示不展示）
    @State private var newLogDraft: LogItem? = nil
    /// 顶部 toast 文案（nil 表示不展示）；toastID 用于相同文案连发时重置计时
    @State private var toastMessage: String? = nil
    @State private var toastID = 0
    /// 入场动画标记（问候区 / 今日概览 / 主双栏，按 Motion.staggerDelay 依次入场）
    @State private var headerAppeared = false
    @State private var overviewAppeared = false
    @State private var columnsAppeared = false

    private var logs: [LogItem] { logEntities.map { $0.toModel() } }
    private var emotions: [EmotionRecord] { emotionEntities.map { $0.toModel() } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GreetingHeaderView(
                    searchText: $searchText,
                    focus: $searchFocused,
                    onNewLog: { presentNewLog(category: .log) },
                    onNewIdea: { presentNewLog(category: .idea) }
                )
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: !headerAppeared && !reduceMotion ? 6 : 0)
                .onAppear { flushSearchRequest() }
                .onChange(of: appState.searchRequestToken) { flushSearchRequest() }

                TodayOverviewView(stats: viewModel.overviewStats)
                    .opacity(overviewAppeared ? 1 : 0)
                    .offset(y: !overviewAppeared && !reduceMotion ? 6 : 0)

                HStack(alignment: .top, spacing: 24) {
                    // 左栏（约 2fr）
                    VStack(spacing: 24) {
                        RecentActivityTimelineView(
                            entries: displayedEntries,
                            title: isSearching ? "搜索结果" : "最近动态",
                            emptyMessage: isSearching ? "没有找到相关记录。" : "今天还没有故事。"
                        ) {
                            appState.selectedModule = .logflow
                        }
                        // 搜索态结果随防抖逐次刷新，关掉隐式过渡避免抖动
                        .animation(isSearching ? nil : listContentAnimation, value: displayedEntries)

                        QuickCaptureCard(draft: $draft, focus: $inputFocused) { module in
                            quickAdd(as: module == .idea ? .idea : .log)
                        }
                        .onAppear { flushNewLogRequest() }
                        .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }

                        if let insight = viewModel.weekInsight {
                            InsightOfWeekCard(headline: insight.headline,
                                              detail: insight.detail,
                                              trend: insight.trend)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // 右栏（约 1fr）
                    EmotionSnapshotCard(
                        emoji: viewModel.emotionSnapshot.emoji,
                        title: viewModel.emotionSnapshot.title,
                        summary: viewModel.emotionSnapshot.summary,
                        points: viewModel.emotionSnapshot.points
                    ) {
                        appState.selectedModule = .emotion
                    }
                    .frame(maxWidth: 300)
                }
                .opacity(columnsAppeared ? 1 : 0)
                .offset(y: !columnsAppeared && !reduceMotion ? 6 : 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncViewModel()
            playEntranceAnimation()
        }
        .onChange(of: logs) { syncViewModel() }
        .onChange(of: emotions) { syncViewModel() }
        .onChange(of: searchText) { scheduleSearchUpdate() }
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
                         title: draftItem.category == .idea ? "新建灵感" : "新建日志") { updated in
                saveNewLog(updated)
            }
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// toast 动效：Motion.spring 轻弹簧；减弱动态时退化为 reducedFade 极短淡变
    private var toastAnimation: Animation? {
        reduceMotion ? Motion.reducedFade(true) : Motion.spring()
    }

    /// 时间线内容变化过渡（走 Motion.soft；减弱动态时直接替换，不做过渡）
    private var listContentAnimation: Animation? {
        Motion.soft(reduceMotion)
    }

    /// 入场动画：三区块 fade + 轻微上移（y 6→0，对齐 .appear 过渡），
    /// 按 staggerDelay 依次入场；减弱动态时 Motion.softOut 返回 nil，只留瞬时呈现
    private func playEntranceAnimation() {
        guard !headerAppeared else { return }
        withAnimation(Motion.softOut(reduceMotion)) { headerAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(1))) { overviewAppeared = true }
        withAnimation(Motion.softOut(reduceMotion)?.delay(Motion.staggerDelay(2))) { columnsAppeared = true }
    }

    // MARK: - 数据注入 / 搜索

    /// 把最新 logs/emotions 注入 ViewModel；内容未变时 VM 内部直接返回，不重算
    private func syncViewModel() {
        viewModel.update(logs: logs, emotions: emotions)
    }

    /// 是否处于搜索态（防抖后的查询词非空）
    private var isSearching: Bool {
        !debouncedQuery.isEmpty
    }

    /// 时间线展示内容：搜索态为全量搜索结果，否则为今天的时间线
    private var displayedEntries: [ActivityEntry] {
        isSearching ? viewModel.searchResultEntries(query: debouncedQuery) : viewModel.recentEntries
    }

    /// 搜索防抖：按键 200ms 后才写入 debouncedQuery 触发过滤；清空时立即还原时间线
    private func scheduleSearchUpdate() {
        searchDebounceTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            debouncedQuery = ""
            return
        }
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            debouncedQuery = query
        }
    }

    // MARK: - 错误提示 / ⌘N / ⌘K / 快速记录 / 新建

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 菜单「新建记录」⌘N：token 递增时聚焦输入框。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushNewLogRequest() {
        guard appState.newLogRequestToken != handledNewLogToken else { return }
        handledNewLogToken = appState.newLogRequestToken
        inputFocused = true
    }

    /// 菜单「搜索」⌘K：token 递增时聚焦搜索框；onAppear 兜底同上
    private func flushSearchRequest() {
        guard appState.searchRequestToken != handledSearchToken else { return }
        handledSearchToken = appState.searchRequestToken
        searchFocused = true
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

    /// LogEditSheet 保存回调：作为新记录入库（id/时间由仓库重新生成）
    private func saveNewLog(_ item: LogItem) {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        do {
            try repository.addLog(content: item.content, colorTag: item.colorTag,
                                  category: item.category, importance: item.importance)
            showToast(item.category == .idea ? "✓ 已保存到灵感" : "✓ 已保存到日志")
        } catch {
            // 弹窗文案固定，详细错误只进控制台（localizedDescription 可能含本机路径）
            print("HomeView: 新建记录保存失败 - \(error)")
            errorMessage = "保存失败，请重试"
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
