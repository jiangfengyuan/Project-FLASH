// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 全局搜索（iOS 版 ⌘K）：跨日志/灵感/情绪/任务搜索（GlobalSearch，与 macOS 同口径），
/// 结果按类型分组（组头带数量）、命中词高亮、日期显示为「今天 / 昨天 / M月d日」；
/// 点结果先关弹层再经 FocusRouter 跨 Tab 定位：记录 → 记录页编辑弹层；情绪 → 情绪页；任务 → 日历日。
struct SearchScreen: View {
    @Environment(\.flashRepository) private var repository
    @Environment(\.dismiss) private var dismiss
    @Environment(FocusRouter.self) private var focusRouter

    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    @State private var query = ""
    @State private var appliedQuery = ""
    @State private var resultsCache = ViewComputeCache<SearchKey, [SearchMatch]>()
    @State private var taskLookupCache = ViewComputeCache<Int, [String: TaskItem]>()

    private struct SearchKey: Equatable {
        let revision: Int
        let query: String
    }

    private var matches: [SearchMatch] {
        resultsCache.value(for: SearchKey(revision: repository?.revision ?? 0, query: appliedQuery)) {
            GlobalSearch.search(logs: logEntities.map { $0.toModel() },
                                emotions: emotionEntities.map { $0.toModel() },
                                tasks: taskEntities.map { $0.toModel() },
                                query: appliedQuery)
        }
    }

    private var taskLookup: [String: TaskItem] {
        taskLookupCache.value(for: repository?.revision ?? 0) {
            Dictionary(uniqueKeysWithValues: taskEntities.map { ($0.id, $0.toModel()) })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if appliedQuery.isEmpty {
                    ContentUnavailableView("搜索记录、灵感、情绪与任务", systemImage: "magnifyingglass",
                                           description: Text("输入关键词或标签名"))
                } else if matches.isEmpty {
                    ContentUnavailableView.search(text: appliedQuery)
                } else {
                    List {
                        ForEach(groupedMatches, id: \.kind) { group in
                            Section {
                                ForEach(group.matches, id: \.id) { match in
                                    Button { open(match) } label: { row(match) }
                                        .buttonStyle(.plain)
                                }
                            } header: {
                                Text("\(group.kind.displayName) · \(group.matches.count)")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L("关键词或标签"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task(id: query) {
                if query.isEmpty { appliedQuery = ""; return }
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                appliedQuery = query
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// 分组顺序固定：记录 → 情绪 → 任务；组内保持 GlobalSearch 的排序
    private var groupedMatches: [(kind: SearchMatchKind, matches: [SearchMatch])] {
        [SearchMatchKind.log, .emotion, .task].compactMap { kind in
            let items = matches.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    private func row(_ match: SearchMatch) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: kindSymbol(match.kind))
                .foregroundStyle(kindColor(match.kind))
                .accessibilityHidden(true)
            Text(highlighted(match.title))
                .font(Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: Spacing.xs)
            Text(relativeDay(match.createdAt))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// 命中词加粗 + 品牌色（大小写不敏感，与 GlobalSearch 同口径）
    private func highlighted(_ title: String) -> AttributedString {
        var text = AttributedString(title)
        let needle = appliedQuery.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return text }
        var searchRange = text.startIndex..<text.endIndex
        while let range = text[searchRange].range(of: needle, options: .caseInsensitive) {
            text[range].foregroundColor = BrandColors.brandPrimary
            text[range].font = Typography.body.weight(.semibold)
            searchRange = range.upperBound..<text.endIndex
        }
        return text
    }

    /// 今天 / 昨天 / 今年内「M月d日」/ 更早「yyyy年M月d日」
    private func relativeDay(_ createdAt: String) -> String {
        let dayString = String(createdAt.prefix(10))
        guard let date = DateFormatting.parseDay(dayString) else { return dayString }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L("今天") }
        if calendar.isDateInYesterday(date) { return L("昨天") }
        let sameYear = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
        return date.formatted(sameYear ? .dateTime.month(.defaultDigits).day()
                                       : .dateTime.year().month(.defaultDigits).day())
    }

    private func kindSymbol(_ kind: SearchMatchKind) -> String {
        switch kind {
        case .log: "square.and.pencil"
        case .emotion: "face.smiling"
        case .task: "checklist"
        }
    }

    private func kindColor(_ kind: SearchMatchKind) -> Color {
        switch kind {
        case .log: BrandColors.logPurple
        case .emotion: BrandColors.emotionPink
        case .task: BrandColors.accessibleGreen
        }
    }

    private func open(_ match: SearchMatch) {
        dismiss()
        switch match.kind {
        case .log: focusRouter.request(.log(match.id))
        case .emotion: focusRouter.request(.emotion)
        case .task: focusRouter.request(.task(taskLookup[match.id]?.calendarDate))
        }
    }
}
