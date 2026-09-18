// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

enum ExploreFilter: String, CaseIterable {
    case all, log, idea, unsorted

    var displayName: String {
        switch self {
        case .all: "全部"
        case .log: "日志"
        case .idea: "灵感"
        case .unsorted: "待整理"
        }
    }
}

/// 记录页：标题「记录」+ 全局搜索 + 筛选胶囊（全部／日志／灵感／待整理）+
/// 筛选面板（标签/重要度/日期范围，popover 承载、关闭后状态保留）+ 记录卡列表。
/// 「待整理」= 未改过分拣的日常日志（category=log 且 colorTag=daily），支持批量修改分类或标签。
/// ⌘K 聚焦搜索框；⌘N 弹「新建记录」面板；列表按最新记录排序。
struct ExploreView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: ExploreFilter = .all
    @State private var searchText = ""
    /// 筛选面板状态（关闭 popover 后保留）
    @State private var criteria = ExploreCriteria()
    @State private var showFilterPanel = false
    @State private var errorMessage: String? = nil
    /// 「+ 新建」sheet 的草稿（nil 表示不展示）
    @State private var newLogDraft: LogItem? = nil
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
                batchBar
            }
            ExploreLogListView(filter: filter, query: searchText, criteria: criteria,
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
        .onAppear { flushSearchRequest(); flushNewLogRequest() }
        .onChange(of: appState.searchRequestToken) { flushSearchRequest() }
        .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }
        .onChange(of: filter) {
            // 离开「待整理」退出批量模式；清空选择避免误操作
            if filter != .unsorted { batchMode = false }
            selection = []
        }
        .sheet(item: $newLogDraft) { draftItem in
            LogEditSheet(log: draftItem,
                         title: draftItem.category == .idea ? "新建灵感" : "新建记录") { updated in
                try saveNewLog(updated)
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
                .font(.title2.bold())
                .foregroundStyle(BrandColors.textPrimary)
            Text(statsSummary)
                .font(.caption)
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
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Text("⌘K")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
                FilterChipView(title: item.displayName, isSelected: filter == item) {
                    filter = item
                }
            }
            Spacer()
            Button {
                showFilterPanel.toggle()
            } label: {
                Image(systemName: criteria.isActive
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(criteria.isActive ? BrandColors.brandPrimary : BrandColors.textSecondary)
                    .frame(width: Metrics.minTouchTarget - 12, height: Metrics.minTouchTarget - 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("筛选")
            .popover(isPresented: $showFilterPanel, arrowEdge: .bottom) {
                ExploreFilterPanel(criteria: $criteria, onClear: clearFilters)
            }
            // 排序状态标签：当前仅「按最新记录」（createdAt 倒序，由列表查询保证），不可点
            Label("按最新记录", systemImage: "arrow.down")
                .font(.caption)
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
                    .font(.caption)
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
                        .font(.callout)
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

    /// 统计摘要：全量记录计数（日志 / 灵感 / 待整理），随数据实时刷新
    private var statsSummary: String {
        let logs = allLogEntities.map { $0.toModel() }
        let logCount = logs.filter { $0.category == .log }.count
        let ideaCount = logs.filter { $0.category == .idea }.count
        let unsortedCount = logs.filter { $0.category == .log && $0.colorTag == .daily }.count
        return "共 \(logs.count) 条 · 日志 \(logCount) · 灵感 \(ideaCount) · 待整理 \(unsortedCount)"
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 清除全部筛选：搜索词 + 筛选面板条件 + 胶囊回到「全部」
    private func clearFilters() {
        searchText = ""
        criteria.clear()
        filter = .all
    }

    private func flushSearchRequest() {
        guard appState.searchRequestToken != appState.handledSearchToken else { return }
        appState.markSearchHandled()
        searchFocused = true
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
                              recordDate: DateFormatting.parseDay(item.recordDate))
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

/// 信息流列表：自带 @Query（静态 category/tag 谓词），与搜索框/面板的 @State 隔离，
/// 每敲一键不再触发全量查询。搜索词与面板条件（标签/重要度/日期范围）在内存中过滤。
private struct ExploreLogListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flashRepository) private var repository
    @Query private var logEntities: [LogEntity]

    let filter: ExploreFilter
    let query: String
    let criteria: ExploreCriteria
    let batchMode: Bool
    @Binding var selection: Set<String>
    let onClearFilters: () -> Void

    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    @State private var errorMessage: String? = nil

    init(filter: ExploreFilter, query: String, criteria: ExploreCriteria,
         batchMode: Bool, selection: Binding<Set<String>>, onClearFilters: @escaping () -> Void) {
        self.filter = filter
        self.query = query
        self.criteria = criteria
        self.batchMode = batchMode
        self._selection = selection
        self.onClearFilters = onClearFilters
        let log = Category.log.rawValue
        let idea = Category.idea.rawValue
        let daily = ColorTag.daily.rawValue
        switch filter {
        case .all:
            _logEntities = Query(sort: \LogEntity.createdAt, order: .reverse)
        case .log:
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == log },
                                 sort: \LogEntity.createdAt, order: .reverse)
        case .idea:
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == idea },
                                 sort: \LogEntity.createdAt, order: .reverse)
        case .unsorted:
            // 待整理：未改过分拣的日常日志（log 且仍挂默认「日常」标签）
            _logEntities = Query(filter: #Predicate<LogEntity> {
                $0.category == log && $0.colorTag == daily
            }, sort: \LogEntity.createdAt, order: .reverse)
        }
    }

    var body: some View {
        Group {
            if displayedLogs.isEmpty {
                emptyState
                    .transition(.appear(reduceMotion: reduceMotion))
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(displayedLogs) { log in
                            row(log)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 新增/删除条目、空态切换均走 soft 过渡
        .animation(Motion.soft(reduceMotion), value: displayedLogs.count)
        .animation(Motion.soft(reduceMotion), value: displayedLogs.isEmpty)
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log,
                         title: log.category == .idea ? "编辑灵感" : "编辑记录") { updated in
                guard let repository else { throw ExploreSaveError.repositoryUnavailable }
                try repository.updateLog(updated)
            }
        }
        .alert(deleteTitle, isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let log = deletingLog {
                    do { try repository?.deleteLog(id: log.id) }
                    catch {
                        print("[ExploreView] 删除记录失败: \(error)")
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

    /// 批量模式下卡片变为可选中（点按切换选择）；否则保持编辑/删除操作
    @ViewBuilder
    private func row(_ log: LogItem) -> some View {
        if batchMode {
            Button {
                if selection.contains(log.id) {
                    selection.remove(log.id)
                } else {
                    selection.insert(log.id)
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: selection.contains(log.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(log.id)
                                         ? BrandColors.brandPrimary : BrandColors.textSecondary)
                    LogCardView(log: log)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection.contains(log.id) ? [.isSelected] : [])
        } else {
            LogCardView(log: log,
                        onEdit: { editingLog = log },
                        onDelete: { deletingLog = log })
                .cardFloat(reduceMotion: reduceMotion)
                .transition(.card(reduceMotion: reduceMotion))
                .contextMenu {
                    Button("编辑…") { editingLog = log }
                    Button("删除", role: .destructive) { deletingLog = log }
                }
        }
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

    private enum ExploreSaveError: Error {
        case repositoryUnavailable
    }

    /// 内存过滤：搜索词（正文/标签名）+ 面板条件（标签/重要度/日期范围，recordDate 字典序即时间序）
    private var displayedLogs: [LogItem] {
        var logs = logEntities.map { $0.toModel() }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !normalized.isEmpty {
            logs = logs.filter { log in
                log.content.lowercased().contains(normalized) ||
                    log.colorTag.displayName.lowercased().contains(normalized)
            }
        }
        if let tag = criteria.tag {
            logs = logs.filter { $0.colorTag == tag }
        }
        if criteria.minImportance > 0 {
            logs = logs.filter { $0.importance >= criteria.minImportance }
        }
        if let start = criteria.startDate {
            let startKey = DateFormatting.dayString(start)
            logs = logs.filter { $0.recordDate >= startKey }
        }
        if let end = criteria.endDate {
            let endKey = DateFormatting.dayString(end)
            logs = logs.filter { $0.recordDate <= endKey }
        }
        return logs
    }

    private var hasActiveFilter: Bool {
        criteria.isActive || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 空状态：有筛选条件时给「没有找到相关记录」+「清除筛选」行动；
    /// 无条件时用品牌化引导文案（PRD §34，不用 "No Data"）
    @ViewBuilder
    private var emptyState: some View {
        if hasActiveFilter {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "没有找到相关记录",
                actionTitle: "清除筛选",
                action: onClearFilters
            )
        } else if filter == .unsorted {
            EmptyStateView(
                systemImage: "tray",
                title: "没有待整理的记录",
                message: "所有日常记录都已经分拣好了。"
            )
        } else {
            let isIdea = filter == .idea
            EmptyStateView(
                systemImage: isIdea ? "lightbulb" : "book",
                title: isIdea ? "灵感还没出现，先给它留个位置。" : "今天还没有故事。",
                message: isIdea ? "在「此刻」页记下第一束灵感" : "在「此刻」页写下第一条记录"
            )
        }
    }
}
