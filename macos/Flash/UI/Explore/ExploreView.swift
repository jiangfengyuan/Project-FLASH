// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 记录页：标题「记录」+ 页内搜索 + 筛选胶囊（全部／日志／灵感／待整理／已收藏）+
/// 筛选面板（标签/重要度/日期范围，popover 承载、关闭后状态保留）+ 记录卡列表。
/// 「待整理」= 未改过分拣的日常日志（category=log 且 colorTag=daily），支持批量修改分类或标签。
/// ⌘K 唤起全局搜索浮层（RootView 层，AppState.isGlobalSearchPresented）；页内搜索是独立的页内过滤能力。
/// ⌘N 弹「新建记录」面板；列表按最新记录排序。
/// 跨模块定位（全局搜索/日历「查看灵感」）：消费 AppState.focusTarget，打开该记录的编辑弹层。
struct ExploreView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: ExploreFilter = .all
    @State private var searchText = ""
    /// 防抖后的搜索词：停顿 200ms 才驱动列表过滤，按键不再逐次触发全表过滤
    @State private var appliedQuery = ""
    /// 只看收藏（筛选胶囊，与面板条件并列）
    @State private var favoritesOnly = false
    /// 统计摘要缓存：键 = 写代际，数据变化才重新全量计数
    @State private var statsSummaryCache = ViewComputeCache<Int, String>()
    /// 筛选面板状态（关闭 popover 后保留）
    @State private var criteria = ExploreCriteria()
    @State private var showFilterPanel = false
    @State private var errorMessage: String? = nil
    /// 「+ 新建」sheet 的草稿（nil 表示不展示）
    @State private var newLogDraft: LogItem? = nil
    /// 跨模块定位：待打开编辑弹层的记录（nil 表示不展示）
    @State private var focusedLog: LogItem? = nil
    /// Idea→Task 转化草稿（nil 表示不展示任务编辑器）
    @State private var ideaTaskDraft: IdeaTaskDraft? = nil
    /// 批量整理模式（仅「待整理」下可用）
    @State private var batchMode = false
    @State private var selection: Set<String> = []
    @FocusState private var searchFocused: Bool

    /// 统计摘要用的轻量全量查询（只取计数，列表本身的谓词查询在子视图中）
    @Query private var allLogEntities: [LogEntity]

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            chipsRow
            if filter == .unsorted {
                Text("待整理：使用日常标签的日志。")
                    .font(Typography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                batchBar
            }
            ExploreLogListView(filter: filter, query: appliedQuery, criteria: criteria,
                               favoritesOnly: favoritesOnly,
                               batchMode: batchMode, selection: $selection,
                               onClearFilters: clearFilters)
                // 筛选切换时强制重建列表查询（@Query 谓词初始化后不随新实例更新）
                .id(filter)
                .transition(.appear(reduceMotion: reduceMotion))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.pageBackground)
        // 筛选切换：结果列表整体 soft 过渡
        .animation(Motion.soft(reduceMotion), value: filter)
        .onAppear { flushNewLogRequest(); flushFocusTarget() }
        .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }
        .onChange(of: appState.focusRequestToken) { flushFocusTarget() }
        .onChange(of: filter) {
            // 离开「待整理」退出批量模式；清空选择避免误操作
            if filter != .unsorted { batchMode = false }
            selection = []
        }
        // 搜索防抖：清空立即生效（清除语义不变），输入停顿 200ms 后才驱动列表过滤
        .task(id: searchText) {
            if searchText.isEmpty {
                if appliedQuery != searchText { appliedQuery = searchText }
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, appliedQuery != searchText else { return }
            appliedQuery = searchText
        }
        .sheet(item: $newLogDraft) { draftItem in
            LogEditSheet(log: draftItem,
                         title: draftItem.category == .idea ? "新建灵感" : "新建记录") { updated in
                try saveNewLog(updated)
            }
        }
        // 跨模块定位：直接打开目标记录的编辑弹层（记录可能不在当前筛选结果里，
        // 弹层不依赖列表命中，最简可靠）
        .sheet(item: $focusedLog) { log in
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
        .sheet(item: $ideaTaskDraft) { draft in
            TaskEditorView(selectedDate: Date(), task: nil, ideaDraft: draft) { task in
                // 入库成功才关闭编辑器（失败保留草稿，错误经 errorMessage 提示）
                if saveTask(task) { ideaTaskDraft = nil }
            }
        }
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 标题行（标题 + 统计摘要 + 新建）

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("记录")
                .flashSectionTitle()
            Text(statsSummary)
                .font(Typography.caption)
                .foregroundStyle(BrandColors.textSecondary)
            Spacer()
            Menu {
                Button("新建记录") { presentNewLog(category: .log) }
                Button("新建灵感") { presentNewLog(category: .idea) }
            } label: {
                Label("新建", systemImage: "plus")
                    .font(.callout.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("新建记录 ⌘N")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandColors.accent)
            TextField("输入关键词或标签", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .focusEffectDisabled()
                .onExitCommand {
                    searchText = ""
                    searchFocused = false
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
                .accessibilityLabel("清除搜索")
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14) // 搜索胶囊横向内距：无对应令牌（sm 偏紧、md 偏宽）
        .padding(.vertical, 11)   // 搜索胶囊纵向内距：特调值，对齐输入框行高
        .background(
            Capsule().fill(Color.primary.opacity(searchFocused ? 0.09 : 0.06))
        )
        .overlay(
            Capsule().strokeBorder(
                searchFocused ? BrandColors.accent.opacity(0.7) : Color.primary.opacity(0.12),
                lineWidth: searchFocused ? 1.5 : 1
            )
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .animation(Motion.quick(reduceMotion), value: searchText.isEmpty)
    }

    // MARK: - 筛选胶囊行 + 筛选面板 + 排序入口

    private var chipsRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(ExploreFilter.allCases, id: \.self) { item in
                // 「灵感」胶囊选中态走模块黄（四模块色），其余保持统一深墨选中
                FilterChipView(title: item.displayName, isSelected: filter == item,
                               accent: item == .idea ? BrandColors.ideaYellow : nil,
                               accentText: item == .idea ? BrandColors.ideaYellowText : nil) {
                    filter = item
                }
            }
            // 「已收藏」胶囊：星标语义用灵感金（与卡片星标同色），勾选后列表只显示收藏项
            FilterChipView(title: "已收藏", isSelected: favoritesOnly,
                           accent: BrandColors.ideaYellow, accentText: BrandColors.ideaYellowText) {
                favoritesOnly.toggle()
            }
            Spacer()
            Button {
                showFilterPanel.toggle()
            } label: {
                Image(systemName: criteria.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .scaledSystemFont(size: 16, relativeTo: .body)
                    .foregroundStyle(criteria.isActive ? BrandColors.brandPrimary : BrandColors.textSecondary)
                    .frame(width: Metrics.minTouchTarget - 12, height: Metrics.minTouchTarget - 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("筛选")
            .accessibilityLabel(criteria.isActive ? "筛选（已启用条件）" : "筛选")
            .popover(isPresented: $showFilterPanel, arrowEdge: .bottom) {
                ExploreFilterPanel(criteria: $criteria, onClear: clearFilters)
            }
            // 排序状态标签：当前仅「按最新记录」（createdAt 倒序，由列表查询保证），不可点
            Label("按最新记录", systemImage: "arrow.down")
                .font(Typography.caption)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - 批量整理（仅「待整理」）

    private var batchBar: some View {
        HStack(spacing: Spacing.sm) {
            Toggle("批量整理", isOn: $batchMode)
                .toggleStyle(.checkbox)
            if batchMode {
                Text("已选 \(selection.count) 条")
                    .font(Typography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                Spacer()
                Menu {
                    // 待整理集合恒为 log 分类，只保留会实际改变数据的「标记为灵感」
                    Button("标记为灵感") { batchSetCategory(.idea) }
                    Divider()
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        Button("标签：\(tag.displayName)") { batchSetTag(tag) }
                    }
                } label: {
                    Text("批量修改分类或标签…")
                        .font(Typography.secondary)
                }
                .menuStyle(.borderlessButton)
                .disabled(selection.isEmpty)
                .opacity(selection.isEmpty ? 0.4 : 1)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    // MARK: - 数据 / 命令处理

    /// 统计摘要：全量记录计数（日志 / 灵感 / 待整理），随数据实时刷新；
    /// 按写代际缓存，搜索按键等无关 body 求值不再全量映射
    private var statsSummary: String {
        statsSummaryCache.value(for: repository?.revision ?? 0) {
            let logs = allLogEntities.map { $0.toModel() }
            let logCount = logs.filter { $0.category == .log }.count
            let ideaCount = logs.filter { $0.category == .idea }.count
            let unsortedCount = logs.filter { $0.category == .log && $0.colorTag == .daily }.count
            return "共 \(logs.count) 条 · 日志 \(logCount) · 灵感 \(ideaCount) · 待整理 \(unsortedCount)"
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 清除全部筛选：搜索词 + 筛选面板条件 + 收藏胶囊 + 胶囊回到「全部」
    private func clearFilters() {
        searchText = ""
        criteria.clear()
        favoritesOnly = false
        filter = .all
    }

    /// 跨模块定位（全局搜索跳转 / 日历「查看灵感」）：消费一次 focusTarget，
    /// 取 logID 对应记录打开编辑弹层。onAppear 兜底：跨模块切换使本视图首次创建时
    /// token 已递增，onChange 不会回放。记录已删时静默忽略（无弹层可开）。
    private func flushFocusTarget() {
        guard let target = appState.consumeFocusTarget(),
              let logID = target.logID,
              let repository else { return }
        focusedLog = (try? repository.allLogs())?.first { $0.id == logID }
    }

    /// 菜单「新建记录」⌘N：在记录页直接弹「新建记录」面板（一次主操作）。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushNewLogRequest() {
        guard appState.newLogRequestToken != appState.handledNewLogToken else { return }
        appState.markNewLogHandled()
        presentNewLog(category: .log)
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
                              isFavorite: item.isFavorite,
                              recordDate: DateFormatting.parseDay(item.recordDate))
    }

    /// Idea→Task 保存：入库 + 重建系统提醒（与日历页同一契约；原灵感保留不动）。
    /// 返回是否入库成功，供 item 型 sheet 决定何时关闭编辑器（失败保留草稿）
    @discardableResult
    private func saveTask(_ task: TaskItem) -> Bool {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return false }
        do {
            try repository.saveTask(task)
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
            return true
        } catch {
            print("[ExploreView] 任务保存失败: \(error)")
            errorMessage = "任务保存失败，请重试"
            return false
        }
    }

    // MARK: - 批量操作

    /// 批量修改分类；逐条 updateLog 入库，任一条失败即中断并提示（已写入的不回滚，
    /// 与单条编辑的粒度一致）
    private func batchSetCategory(_ category: Category) {
        batchUpdate { $0.category = category }
    }

    private func batchSetTag(_ tag: ColorTag) {
        batchUpdate { $0.colorTag = tag }
    }

    private func batchUpdate(_ mutate: (inout LogItem) -> Void) {
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        // 批量操作取数快照：直接从仓库读全量，避免把列表的 @Query 数据回传给父级
        let snapshotLogs = (try? repository.allLogs()) ?? []
        for id in selection {
            guard var log = snapshotLogs.first(where: { $0.id == id }) else { continue }
            mutate(&log)
            do { try repository.updateLog(log) }
            catch {
                print("[ExploreView] 批量更新失败: \(error)")
                errorMessage = "批量修改失败，请重试"
                return
            }
        }
        selection = []
        batchMode = false
    }
}
