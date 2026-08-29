// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData

enum ExploreFilter: String, CaseIterable {
    case all, log, idea

    var displayName: String {
        switch self {
        case .all: "全部"
        case .log: "日志"
        case .idea: "灵感"
        }
    }
}

/// 探索页：统一信息流（日志+灵感），模块筛选 + 底部快速输入
struct ExploreView: View {
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: ExploreFilter = .all
    @State private var draft = ""
    @State private var selectedTag: ColorTag? = nil
    @State private var errorMessage: String? = nil
    @FocusState private var inputFocused: Bool

    private static let maxLength = 140

    var body: some View {
        VStack(spacing: 0) {
            // 模块筛选 chips：选中态弹簧动效 + hover 微反馈
            HStack(spacing: 8) {
                ForEach(ExploreFilter.allCases, id: \.self) { item in
                    FilterChip(item: item, isSelected: filter == item, reduceMotion: reduceMotion) {
                        filter = item
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ExploreLogListView(filter: filter)
                // 筛选切换时强制重建列表查询（@Query 谓词初始化后不随新实例更新）
                .id(filter)
                .transition(.appear(reduceMotion: reduceMotion))

            Divider()

            // 底部快速输入
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(ColorTag.allCases, id: \.self) { tag in
                        tagButton(tag)
                    }
                    Spacer()
                    Text("\(draft.count)/\(Self.maxLength)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(filter == .idea ? "记录灵感（!! 标记重要度）…" : "记录此刻…",
                              text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .focused($inputFocused)
                        .onAppear { flushNewLogRequest() }
                        .onChange(of: appState.newLogRequestToken) { flushNewLogRequest() }
                        .onChange(of: draft) {
                            if draft.count > Self.maxLength {
                                draft = String(draft.prefix(Self.maxLength))
                            }
                        }
                    Button("发送") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        // 筛选切换：结果列表整体 soft 过渡（chips 选中态由 FilterChip 内部 spring 接管）
        .animation(Motion.soft(reduceMotion), value: filter)
        .alert("提示", isPresented: errorPresented) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func tagButton(_ tag: ColorTag) -> some View {
        let isSelected = selectedTag == tag
        return Button {
            selectedTag = isSelected ? nil : tag
        } label: {
            Circle()
                .fill(tag.color)
                .frame(width: 18, height: 18)
                .scaleEffect(isSelected && !reduceMotion ? 1.1 : 1)
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(Color.primary, lineWidth: 2)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(Motion.spring(reduceMotion), value: isSelected)
        .help(tag.displayName)
        .accessibilityLabel(tag.displayName)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    /// 菜单「新建记录」⌘N：token 递增时聚焦输入框。
    /// onAppear 兜底：跨模块命令使本视图首次创建时 token 已递增，onChange 不会回放。
    private func flushNewLogRequest() {
        guard appState.newLogRequestToken != appState.handledNewLogToken else { return }
        appState.markNewLogHandled()
        inputFocused = true
    }

    private func save() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard let repository else { errorMessage = "内部错误：存储未就绪"; return }
        let asIdea = filter == .idea
        let tag = selectedTag ?? (asIdea ? .idea : .daily)
        do {
            try repository.addLog(
                content: content,
                colorTag: tag,
                category: asIdea ? .idea : .log,
                importance: asIdea ? importanceFromContent(content) : 0
            )
            draft = ""
            selectedTag = nil
        } catch {
            // 固定文案，详情仅输出到控制台，避免向用户暴露内部路径
            print("[ExploreView] 保存记录失败: \(error)")
            errorMessage = "保存失败，请重试"
        }
    }
}

/// 筛选 chip：选中胶囊用模块色（§29 低饱和强调色），spring 入场；未选中 hover 淡底
private struct FilterChip: View {
    let item: ExploreFilter
    let isSelected: Bool
    let reduceMotion: Bool
    let action: () -> Void

    @State private var hovering = false

    private var tint: Color {
        switch item {
        case .all: BrandColors.accent
        case .log: BrandColors.logPurple
        case .idea: BrandColors.ideaYellow
        }
    }

    var body: some View {
        Button(action: action) {
            Text(item.displayName)
                .font(.callout)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(tint.opacity(0.14))
                            .overlay {
                                Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 0.5)
                            }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else if hovering {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .transition(.opacity)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Motion.spring(reduceMotion), value: isSelected)
        .animation(Motion.quick(reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// 信息流列表：自带 @Query（静态 category 谓词），与底部输入框的 draft 状态隔离，
/// 每敲一键不再触发全量 map。
private struct ExploreLogListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var logEntities: [LogEntity]

    let filter: ExploreFilter

    init(filter: ExploreFilter) {
        self.filter = filter
        switch filter {
        case .all:
            _logEntities = Query(sort: \LogEntity.createdAt, order: .reverse)
        case .log:
            let category = Category.log.rawValue
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == category },
                                 sort: \LogEntity.createdAt, order: .reverse)
        case .idea:
            let category = Category.idea.rawValue
            _logEntities = Query(filter: #Predicate<LogEntity> { $0.category == category },
                                 sort: \LogEntity.createdAt, order: .reverse)
        }
    }

    var body: some View {
        Group {
            if logEntities.isEmpty {
                emptyState
                    .transition(.appear(reduceMotion: reduceMotion))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(logEntities.map { $0.toModel() }) { log in
                            LogCardView(log: log)
                                .cardFloat(reduceMotion: reduceMotion)
                                .transition(.card(reduceMotion: reduceMotion))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 新增/删除条目、空态切换均走 soft 过渡
        .animation(Motion.soft(reduceMotion), value: logEntities.count)
        .animation(Motion.soft(reduceMotion), value: logEntities.isEmpty)
    }

    /// 空状态：PRD §34 品牌化文案，不用 "No Data"
    private var emptyState: some View {
        let isIdea = filter == .idea
        return VStack(spacing: 10) {
            Image(systemName: isIdea ? "lightbulb" : "book")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(isIdea ? BrandColors.ideaYellow : BrandColors.logPurple)
            Text(isIdea ? "灵感还没出现，先给它留个位置。" : "今天还没有故事。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(isIdea ? "在下方记下第一束灵感" : "在下方写下第一条记录")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
