// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

/// 记录流：搜索 + 标签/日期/排序筛选 + 编辑删除（对齐 Android LogFlowViewModel）
struct LogFlowView: View {
    @Environment(\.flashRepository) private var repository
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]

    @State private var filter = LogFilter()
    /// .searchable 的原始输入；停顿 200ms 后才写入 filter.query 驱动全表过滤
    @State private var searchInput = ""
    /// 过滤结果缓存：键 = 写代际 + 完整过滤条件，无关重渲染命中缓存
    @State private var filteredCache = ViewComputeCache<FilteredKey, [LogItem]>()
    @State private var editingLog: LogItem? = nil
    @State private var deletingLog: LogItem? = nil
    @State private var errorMessage: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 缓存键：数据写代际 + 过滤条件（含搜索词/标签/日期/排序）
    private struct FilteredKey: Equatable {
        let revision: Int
        let filter: LogFilter
    }

    var body: some View {
        // 过滤条件或数据变化时才过滤一次，空态与列表复用同一结果
        let filtered = filteredCache.value(for: FilteredKey(revision: repository?.revision ?? 0,
                                                            filter: filter)) {
            filter.apply(to: logEntities.map { $0.toModel() })
        }
        VStack(spacing: 0) {
            // 工具区
            VStack(spacing: 10) { // 10：工具区行距特调（xs 偏紧、sm 偏松）
                HStack(spacing: Spacing.xs) {
                    // 「想法」标签只挂在 category == .idea 的灵感上，而 LogFilter 只保留
                    // category == .log（LogFilter.apply），选中它永远无结果，故不出现在筛选 chips
                    ForEach(ColorTag.allCases.filter { $0 != .idea }, id: \.self) { tag in
                        tagChip(tag)
                    }
                    Spacer()
                    Picker("排序", selection: $filter.sort) {
                        ForEach(LogSort.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }
                HStack(spacing: Spacing.xs) {
                    DatePicker("开始", selection: startBinding, displayedComponents: .date)
                        .labelsHidden()
                        .opacity(filter.startDate == nil ? 0.45 : 1)
                    Text("至").foregroundStyle(.secondary)
                    DatePicker("结束", selection: endBinding, displayedComponents: .date)
                        .labelsHidden()
                        .opacity(filter.endDate == nil ? 0.45 : 1)
                    if filter.startDate != nil || filter.endDate != nil {
                        Button("清除日期") {
                            filter.startDate = nil
                            filter.endDate = nil
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BrandColors.accent)
                        .transition(.opacity)
                    }
                    Spacer()
                }
                .font(Typography.caption)
            }
            .padding(Spacing.sm)

            Divider()

            if filtered.isEmpty {
                // PRD §34：空态用品牌化 EmptyStateView（内置 .appear 过渡，不再叠加）；
                // 筛选无结果时保留搜索语义
                if logEntities.isEmpty {
                    EmptyStateView(
                        systemImage: "square.and.pencil",
                        title: "今天还没有故事。",
                        message: "在「此刻」页写下第一条记录",
                        iconTint: BrandColors.logPurple
                    )
                } else {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "没有匹配的记录",
                        message: "换个关键词或调整筛选条件试试。"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(filtered) { log in
                            LogCardView(log: log,
                                        onEdit: { editingLog = log },
                                        onDelete: { deletingLog = log })
                                .contextMenu {
                                    Button("编辑…") { editingLog = log }
                                    Button("删除", role: .destructive) { deletingLog = log }
                                }
                        }
                    }
                    .padding(Spacing.md)
                    // 列表插入/删除/筛选切换统一 Motion.soft；行重排走默认 move
                    .animation(Motion.soft(reduceMotion), value: filtered)
                }
                .transition(.appear(reduceMotion: reduceMotion))
            }
        }
        // 空态 ↔ 列表切换的过渡动画
        .animation(Motion.soft(reduceMotion), value: filtered.isEmpty)
        .searchable(text: $searchInput, placement: .toolbar, prompt: "搜索记录内容")
        // 搜索防抖：清空立即生效（语义不变），输入停顿 200ms 后才驱动全表过滤排序
        .task(id: searchInput) {
            if searchInput.isEmpty {
                if filter.query != searchInput { filter.query = searchInput }
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, filter.query != searchInput else { return }
            filter.query = searchInput
        }
        .sheet(item: $editingLog) { log in
            LogEditSheet(log: log) { updated in
                try repository?.updateLog(updated)
            }
        }
        .alert("删除这条记录？", isPresented: deletePresented) {
            Button("删除", role: .destructive) {
                if let log = deletingLog {
                    do { try repository?.deleteLog(id: log.id) }
                    catch {
                        print("[LogFlowView] 删除记录失败: \(error)")
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

    // 日期桥接：filter 存 yyyy-MM-dd 字符串（对齐 Web/Android），DatePicker 用 Date
    private var startBinding: Binding<Date> {
        Binding(
            get: { filter.startDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.startDate = DateFormatting.dayString($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { filter.endDate.flatMap(DateFormatting.parseDay) ?? Date() },
            set: { filter.endDate = DateFormatting.dayString($0) }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(get: { deletingLog != nil }, set: { if !$0 { deletingLog = nil } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func tagChip(_ tag: ColorTag) -> some View {
        let isOn = filter.tags.contains(tag)
        return Button {
            if isOn { filter.tags.remove(tag) } else { filter.tags.insert(tag) }
        } label: {
            Text(tag.displayName)
                .font(Typography.caption)
                .padding(.horizontal, 10) // 紧凑胶囊横向内距（无对应令牌）
                .padding(.vertical, Spacing.xxs)
                .background(isOn ? tag.color.opacity(0.25)
                                 : BrandColors.cardSurface)
                .foregroundStyle(.primary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(isOn ? tag.color
                                          : BrandColors.weakBorder,
                                     lineWidth: 1)
                }
                .animation(Motion.quick(reduceMotion), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
