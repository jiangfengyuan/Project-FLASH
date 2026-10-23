// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore

/// 信息流列表：自带 @Query（静态 category/tag 谓词），与搜索框/面板的 @State 隔离，
/// 每敲一键不再触发全量查询。搜索词与面板条件（标签/重要度/日期范围/收藏）在内存中过滤，
/// 过滤逻辑由 Domain 的 ExploreLogFilter 承担（本视图只做装配与缓存键）。
public struct ExploreLogListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flashRepository) private var repository
    @Query private var logEntities: [LogEntity]

    public let filter: ExploreFilter
    public let query: String
    public let criteria: ExploreCriteria
    public let favoritesOnly: Bool
    public let batchMode: Bool
    @Binding public var selection: Set<String>
    public let onClearFilters: () -> Void

    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    @State private var errorMessage: String? = nil
    /// Idea→Task 转化草稿（nil 表示不展示任务编辑器）
    @State private var ideaTaskDraft: IdeaTaskDraft? = nil

    public init(filter: ExploreFilter, query: String, criteria: ExploreCriteria, favoritesOnly: Bool,
         batchMode: Bool, selection: Binding<Set<String>>, onClearFilters: @escaping () -> Void) {
        self.filter = filter
        self.query = query
        self.criteria = criteria
        self.favoritesOnly = favoritesOnly
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

    public var body: some View {
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
                         title: log.category == .idea ? "编辑灵感" : "编辑记录",
                         onSave: { updated in
                             guard let repository else { throw ExploreSaveError.repositoryUnavailable }
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
                        onDelete: { deletingLog = log },
                        onToggleFavorite: { toggleFavorite(log) })
                .cardFloat(reduceMotion: reduceMotion)
                .transition(.card(reduceMotion: reduceMotion))
                .contextMenu {
                    Button("编辑…") { editingLog = log }
                    Button(log.isFavorite == true ? "取消收藏" : "收藏") { toggleFavorite(log) }
                    if log.category == .idea {
                        Button("转为任务") {
                            ideaTaskDraft = IdeaTaskDraft(sourceLogId: log.id, title: log.content)
                        }
                    }
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

    /// displayedLogs 缓存：键 = 写代际 + Domain 过滤条件（搜索词/标签/重要度/日期范围/收藏）。
    /// 不能用 @Query 实体数组做键：PersistentModel 相等走身份，漏掉就地属性更新。
    @State private var displayedCache = ViewComputeCache<DisplayedKey, [LogItem]>()

    private struct DisplayedKey: Equatable {
        let revision: Int
        let filter: ExploreLogFilter
    }

    /// 内存过滤：装配 ExploreLogFilter（Domain 纯函数）后按缓存键 memo 化；
    /// 无关重渲染与每次按键不再全表映射。类别由 @Query 谓词在 DB 层先筛（categories 传 nil）
    private var displayedLogs: [LogItem] {
        let domainFilter = ExploreLogFilter(
            query: query,
            tag: criteria.tag,
            minImportance: criteria.minImportance,
            startDate: criteria.startDate.map(DateFormatting.dayString),
            endDate: criteria.endDate.map(DateFormatting.dayString),
            favoritesOnly: favoritesOnly)
        return displayedCache.value(for: DisplayedKey(revision: repository?.revision ?? 0,
                                                      filter: domainFilter)) {
            domainFilter.apply(to: logEntities.map { $0.toModel() })
        }
    }

    private var hasActiveFilter: Bool {
        criteria.isActive || favoritesOnly
            || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func toggleFavorite(_ log: LogItem) {
        do { try repository?.setLogFavorite(id: log.id, !(log.isFavorite ?? false)) }
        catch {
            print("[ExploreView] 收藏切换失败: \(error)")
            errorMessage = "操作失败，请重试"
        }
    }

    /// Idea→Task 保存：入库 + 重建系统提醒（与日历页同一契约；原灵感保留不动）。
    /// 返回是否入库成功，供 item 型 sheet 决定何时关闭编辑器（失败保留草稿）
    @discardableResult
    private func saveTask(_ task: TaskItem) -> Bool {
        do {
            guard let repository else { throw ExploreSaveError.repositoryUnavailable }
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
                message: isIdea ? "在「此刻」页记下第一束灵感" : "在「此刻」页写下第一条记录",
                iconTint: isIdea ? BrandColors.ideaYellow : BrandColors.logPurple
            )
        }
    }
}
