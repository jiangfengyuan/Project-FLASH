// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 记录页（iOS 外壳）：页内搜索（系统搜索栏，200ms 防抖）+ 筛选胶囊（全部/日志/灵感/待整理/已收藏）
/// + 筛选面板（sheet）+ 记录列表（共享 ExploreLogListView：点按编辑、轻扫收藏/删除）。
/// 「待整理」支持「选择」模式（底部工具栏批量改分类或标签）；跨模块定位（全局搜索/日历「查看灵感」）在此打开编辑弹层。
struct ExploreScreen: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(FocusRouter.self) private var focusRouter
    @Environment(AppState.self) private var appState
    @Environment(\.flashMarkIdeaViewed) private var markIdeaViewed

    @State private var filter: ExploreFilter = .all
    @State private var searchText = ""
    /// 防抖后的搜索词：停顿 200ms 才驱动列表过滤（清空立即生效）
    @State private var appliedQuery = ""
    @State private var favoritesOnly = false
    @State private var criteria = ExploreCriteria()
    @State private var showFilterSheet = false
    @State private var newLogDraft: LogItem? = nil
    /// 跨模块定位：待打开编辑弹层的记录
    @State private var focusedLog: LogItem? = nil
    @State private var ideaTaskDraft: IdeaTaskDraft? = nil
    @State private var batchMode = false
    @State private var selection: Set<String> = []
    @State private var errorMessage: String? = nil
    @State private var toast: FlashToast? = nil
    @State private var statsSummaryCache = ViewComputeCache<Int, String>()

    /// 统计摘要用的全量查询（列表本身的谓词查询在共享子视图中）
    @Query private var allLogEntities: [LogEntity]

    var body: some View {
        VStack(spacing: 0) {
            chipsRow
            if filter == .unsorted {
                unsortedBar
            }
            ExploreLogListView(filter: filter, query: appliedQuery, criteria: criteria,
                               favoritesOnly: favoritesOnly,
                               batchMode: batchMode, selection: $selection,
                               onClearFilters: clearFilters)
                // 筛选切换时强制重建列表查询（@Query 谓词初始化后不随新实例更新）
                .id(filter)
                .transition(.appear(reduceMotion: reduceMotion))
        }
        .flashPageBackground()
        .navigationTitle("记录")
        .navigationSubtitleIfAvailable(statsSummary)
        // 搜索栏常显（不必下拉才出现）
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L("输入关键词或标签"))
        .toolbar { toolbarContent }
        .toolbar { batchToolbar }
        .toolbar(batchMode ? .hidden : .automatic, for: .tabBar)
        .flashToast($toast)
        .sensoryFeedback(.success, trigger: toast) { _, new in new != nil }
        .animation(Motion.soft(reduceMotion), value: filter)
        .animation(Motion.quick(reduceMotion), value: batchMode)
        .onChange(of: filter) {
            if filter != .unsorted { batchMode = false }
            selection = []
        }
        .task(id: searchText) {
            if searchText.isEmpty {
                if appliedQuery != searchText { appliedQuery = searchText }
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, appliedQuery != searchText else { return }
            appliedQuery = searchText
        }
        .onAppear { flushFocusTarget(); flushFilterRequest() }
        .onChange(of: focusRouter.requestToken) { flushFocusTarget() }
        .onChange(of: appState.exploreFilterRequest) { flushFilterRequest() }
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                ScrollView {
                    ExploreFilterPanel(criteria: $criteria, onClear: clearFilters)
                        .padding(Spacing.card)
                }
                .flashPageBackground()
                .navigationTitle("筛选")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showFilterSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $newLogDraft) { draftItem in
            LogEditSheet(log: draftItem,
                         title: draftItem.category == .idea ? L("新建灵感") : L("新建记录")) { updated in
                try saveNewLog(updated)
            }
        }
        .sheet(item: $focusedLog) { log in
            LogEditSheet(log: log,
                         title: log.category == .idea ? L("编辑灵感") : L("编辑记录"),
                         onSave: { updated in
                             guard let repository else { throw SaveError() }
                             try repository.updateLog(updated)
                         },
                         onConvertToTask: { draft in
                             ideaTaskDraft = IdeaTaskDraft(sourceLogId: draft.id, title: draft.content)
                         })
        }
        .sheet(item: $ideaTaskDraft) { draft in
            TaskEditorView(selectedDate: Date(), task: nil, ideaDraft: draft) { task in
                if saveTask(task) { ideaTaskDraft = nil }
            }
        }
        .alert("操作失败", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // 「待整理」：系统惯用的「选择 / 完成」进入批量模式
        if filter == .unsorted {
            ToolbarItem(placement: .topBarLeading) {
                Button(batchMode ? L("完成") : L("选择")) {
                    batchMode.toggle()
                    if !batchMode { selection = [] }
                }
                .fontWeight(batchMode ? .semibold : .regular)
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: criteria.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel(criteria.isActive ? L("筛选（已启用条件）") : L("筛选"))

            Menu {
                Button("新建记录", systemImage: "square.and.pencil") { presentNewLog(category: .log) }
                Button("新建灵感", systemImage: "lightbulb") { presentNewLog(category: .idea) }
                Divider()
                Button("日志流", systemImage: "list.bullet.rectangle") { appState.explorePath.append(.logFlow) }
                Button("全局搜索", systemImage: "magnifyingglass") { appState.isSearchPresented = true }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("新建与更多")
        }
    }

    // MARK: - 筛选胶囊

    /// 单选分类胶囊 | 分隔线 | 可叠加的「已收藏」开关（星标区分两种语义）
    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(ExploreFilter.allCases, id: \.self) { item in
                    FilterChipView(title: item.displayName, isSelected: filter == item,
                                   accent: item == .idea ? BrandColors.ideaYellow : nil,
                                   accentText: item == .idea ? BrandColors.ideaYellowText : nil) {
                        filter = item
                    }
                }
                FlashDivider(seed: "explore-chips", axis: .vertical)
                    .frame(height: 20) // 分隔线高度约等于胶囊文字行高（几何值）
                    .padding(.horizontal, Spacing.xxs)
                FilterChipView(title: L("已收藏"), isSelected: favoritesOnly,
                               accent: BrandColors.ideaYellow, accentText: BrandColors.ideaYellowText,
                               systemImage: favoritesOnly ? "star.fill" : "star") {
                    favoritesOnly.toggle()
                }
                .accessibilityHint("与分类筛选叠加")
            }
            .flashPageGutter()
            .padding(.vertical, Spacing.sm)
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    // MARK: - 待整理 / 批量

    private var unsortedBar: some View {
        Text(batchMode ? L("点选要整理的日志，在底部批量修改。") : L("待整理：仍挂「日常」标签的日志。点「选择」可批量整理。"))
            .font(Typography.caption)
            .foregroundStyle(BrandColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .flashPageGutter()
            .padding(.bottom, Spacing.xs)
    }

    /// 选择模式底部工具栏：已选数量 + 标记为灵感 + 改标签
    @ToolbarContentBuilder
    private var batchToolbar: some ToolbarContent {
        if batchMode {
            ToolbarItem(placement: .bottomBar) {
                Button("标记为灵感", systemImage: "lightbulb") {
                    batchUpdate { $0.category = .idea }
                }
                .disabled(selection.isEmpty)
            }
            ToolbarItem(placement: .status) {
                Text(selection.isEmpty ? L("未选择") : L("已选 \(selection.count) 条"))
                    .font(Typography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .contentTransition(.numericText())
            }
            ToolbarItem(placement: .bottomBar) {
                Menu {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        Button(tag.displayName) { batchUpdate { $0.colorTag = tag } }
                    }
                } label: {
                    Label("改标签", systemImage: "tag")
                }
                .disabled(selection.isEmpty)
            }
        }
    }

    // MARK: - 数据

    private var statsSummary: String {
        statsSummaryCache.value(for: repository?.revision ?? 0) {
            let logs = allLogEntities.map { $0.toModel() }
            let logCount = logs.filter { $0.category == .log }.count
            let ideaCount = logs.filter { $0.category == .idea }.count
            return L("共 \(logs.count) 条 · 日志 \(logCount) · 灵感 \(ideaCount)")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func clearFilters() {
        searchText = ""
        criteria.clear()
        favoritesOnly = false
        filter = .all
    }

    /// 跨模块定位：只消费「记录」目标（其它 Tab 的目标留给对应页面）
    private func flushFocusTarget() {
        guard case .log(let logID)? = focusRouter.consume(matching: { if case .log = $0 { true } else { false } }),
              let repository else { return }
        focusedLog = (try? repository.allLogs())?.first { $0.id == logID }
        // 灵感经定位打开（此刻提示行 / 搜索 / 日历「查看灵感」）即视为已读
        if focusedLog?.category == .idea { markIdeaViewed?(logID) }
    }

    /// 深链 / 灵感提醒指定的筛选（如 flash://ideas → 灵感），消费一次
    private func flushFilterRequest() {
        guard let request = appState.exploreFilterRequest else { return }
        appState.exploreFilterRequest = nil
        clearFilters()
        filter = request
    }

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

    private func saveNewLog(_ item: LogItem) throws {
        guard let repository else { throw SaveError() }
        try repository.addLog(content: item.content, colorTag: item.colorTag,
                              category: item.category, importance: item.importance,
                              isFavorite: item.isFavorite,
                              recordDate: DateFormatting.parseDay(item.recordDate))
    }

    @discardableResult
    private func saveTask(_ task: TaskItem) -> Bool {
        guard let repository else { errorMessage = L("内部错误：存储未就绪"); return false }
        do {
            try repository.saveTask(task)
            Task {
                if let warning = await TaskSaving.scheduleReminder(for: task) { errorMessage = warning }
            }
            return true
        } catch {
            FlashLog.failure("task_save_failed", error)
            errorMessage = L("任务保存失败，请重试")
            return false
        }
    }

    /// 批量修改：逐条 updateLog，任一条失败即中断并提示（已写入的不回滚，与单条编辑粒度一致）
    private func batchUpdate(_ mutate: (inout LogItem) -> Void) {
        guard let repository else { errorMessage = L("内部错误：存储未就绪"); return }
        let snapshotLogs = (try? repository.allLogs()) ?? []
        for id in selection {
            guard var log = snapshotLogs.first(where: { $0.id == id }) else { continue }
            mutate(&log)
            do { try repository.updateLog(log) }
            catch {
                FlashLog.failure("batch_update_failed", error)
                errorMessage = L("批量修改失败，请重试")
                return
            }
        }
        toast = FlashToast(L("✓ 已整理 \(selection.count) 条"))
        selection = []
        batchMode = false
    }
}

private extension View {
    /// iOS 26 起导航栏支持副标题；更早版本不显示（摘要非关键信息）
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ text: String) -> some View {
        if #available(iOS 26.0, *) {
            navigationSubtitle(text)
        } else {
            self
        }
    }
}
