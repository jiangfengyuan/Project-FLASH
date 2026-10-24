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
                    List(matches, id: \.id) { match in
                        Button { open(match) } label: { row(match) }
                            .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "关键词或标签")
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

    private func row(_ match: SearchMatch) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(match.kind.displayName)
                .font(Typography.caption)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2) // 徽章纵向内距（几何值）
                .background(kindColor(match.kind).opacity(0.15), in: Capsule())
                .foregroundStyle(kindColor(match.kind))
            Text(match.title)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: Spacing.xs)
            Text(String(match.createdAt.prefix(10)))
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
