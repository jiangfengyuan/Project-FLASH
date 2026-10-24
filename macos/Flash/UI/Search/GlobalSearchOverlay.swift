// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 全局搜索浮层（PRD §23）：⌘K 唤起，Spotlight 风格居中靠上面板。
/// 悬浮层玻璃（.flashGlassBackground），输入 200ms 防抖即时搜索（Domain/GlobalSearch，
/// 日志+情绪+任务三实体），结果显示类型徽章 + 标题 + 日期；Esc 关闭，↑↓ 选择，Enter 跳转。
/// 跳转走 AppState.requestFocus 跨模块定位：记录/灵感 → 记录页打开编辑弹层；
/// 情绪 → 情绪页；任务 → 日历页选中其日期。
struct GlobalSearchOverlay: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let close: () -> Void

    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    @State private var query = ""
    /// 防抖后的搜索词（与记录页/日志流同一 200ms 惯例；清空立即生效）
    @State private var appliedQuery = ""
    @State private var selectedIndex = 0
    @FocusState private var fieldFocused: Bool

    /// 结果缓存：键 = 写代际 + 搜索词；面板内按键/选中移动不再全表映射
    @State private var resultsCache = ViewComputeCache<SearchKey, [SearchMatch]>()
    /// 任务反查表（跳转日历日用）：键 = 写代际
    @State private var taskLookupCache = ViewComputeCache<Int, [String: TaskItem]>()

    private struct SearchKey: Equatable {
        let revision: Int
        let query: String
    }

    private var matches: [SearchMatch] {
        resultsCache.value(for: SearchKey(revision: repository?.revision ?? 0,
                                          query: appliedQuery)) {
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
        ZStack(alignment: .top) {
            // 遮罩：点击外部关闭
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityHidden(true)

            panel
                .padding(.top, 120) // 面板距窗口顶部（Spotlight 风格靠上，几何值）
        }
        .onAppear { fieldFocused = true }
        // 搜索防抖：清空立即生效，输入停顿 200ms 后才驱动搜索
        .task(id: query) {
            if query.isEmpty {
                if appliedQuery != query { appliedQuery = query }
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, appliedQuery != query else { return }
            appliedQuery = query
        }
        .onChange(of: appliedQuery) { selectedIndex = 0 }
    }

    // MARK: - 面板

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BrandColors.accent)
                TextField("搜索记录、情绪、任务…", text: $query)
                    .textFieldStyle(.plain)
                    .font(Typography.body)
                    .focused($fieldFocused)
                    .focusEffectDisabled()
                    .onSubmit { openSelected() }
                    .onExitCommand { close() }
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                if !query.isEmpty {
                    Button {
                        query = ""
                        fieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("清除搜索")
                    .accessibilityLabel("清除搜索")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            if appliedQuery.isEmpty {
                Text("输入关键词，跨记录、情绪与任务搜索")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.sm)
            } else if matches.isEmpty {
                Text("没有找到「\(appliedQuery)」相关的内容")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.lg)
            } else {
                Divider().opacity(0.5)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                            resultRow(match, isSelected: index == selectedIndex) {
                                open(match)
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                .frame(maxHeight: 380) // 结果列表最大高度（几何值）
                Divider().opacity(0.5)
                Text("↑↓ 选择 · ⏎ 打开 · esc 关闭")
                    .font(Typography.fine)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Spacing.xs)
            }
        }
        .frame(width: 560) // 搜索面板固有宽度（几何值）
        .flashGlassBackground(in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .flashElevatedShadow()
    }

    // MARK: - 结果行

    private func resultRow(_ match: SearchMatch, isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                // 类型徽章：模块色小圆点 + 类型文字（颜色仅点缀，不靠颜色单独区分）
                Circle()
                    .fill(kindColor(match.kind))
                    .frame(width: 6, height: 6) // 类型色点尺寸（几何值）
                Text(match.kind.displayName)
                    .font(Typography.fine)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading) // 徽章列宽（几何值）
                Text(match.title)
                    .font(Typography.secondary)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(String(match.createdAt.prefix(10))) // ISO 前缀即 yyyy-MM-dd
                    .font(Typography.fine)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(BrandColors.accent.opacity(0.15))
                        .padding(.horizontal, Spacing.xs)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func kindColor(_ kind: SearchMatchKind) -> Color {
        switch kind {
        case .log: BrandColors.logPurple
        case .emotion: BrandColors.emotionPink
        case .task: BrandColors.calendarGreen
        }
    }

    // MARK: - 键盘与跳转

    private func moveSelection(_ delta: Int) {
        guard !matches.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), matches.count - 1)
    }

    private func openSelected() {
        guard matches.indices.contains(selectedIndex) else { return }
        open(matches[selectedIndex])
    }

    /// 跳转：先关浮层再发跨模块定位（同事务切模块，目标页 onAppear/onChange 消费）
    private func open(_ match: SearchMatch) {
        close()
        switch match.kind {
        case .log:
            appState.requestFocus(.log(match.id))
        case .emotion:
            appState.requestFocus(.emotion)
        case .task:
            // 任务定位到其日历日；无截止时间（calendarDate 为 nil）时仅切到日历页
            appState.requestFocus(.task(on: taskLookup[match.id]?.calendarDate))
        }
    }
}
