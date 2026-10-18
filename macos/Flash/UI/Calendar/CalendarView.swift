// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import SwiftData
import FlashCore
import FlashDesign

/// 日历页：月视图网格 + 选中日详情（对齐 Android CalendarViewModel）
struct CalendarView: View {
    @Query(sort: \LogEntity.createdAt, order: .reverse) private var logEntities: [LogEntity]
    @Query(sort: \EmotionEntity.createdAt, order: .reverse) private var emotionEntities: [EmotionEntity]
    @Query(sort: \TaskEntity.updatedAt, order: .reverse) private var taskEntities: [TaskEntity]

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var editingTask: TaskItem?
    @State private var showingTaskEditor = false
    @State private var message: String?
    /// 月份切换方向：+1 前进 / -1 后退 / 0 无方向（回到本月），驱动方向性过渡
    @State private var monthDirection = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flashRepository) private var repository
    @Environment(AppState.self) private var appState

    /// 聚合结果缓存：仅在数据写代际变化时重算；月份切换/选中日/hover 不再触发全表聚合。
    /// 键不含 displayedMonth：aggregateDay 对全部日期产出字典，与展示月份无关。
    /// 不能用 @Query 实体数组做键：PersistentModel 相等走身份，漏掉勾选完成等就地更新。
    @State private var aggregateCache = ViewComputeCache<Int, [String: DayAggregate]>()

    /// 共享公历实例，避免每次渲染格子都新建 Calendar
    nonisolated(unsafe) private static let gregorian = Calendar(identifier: .gregorian)

    private var weeks: [[Date]] { CalendarGrid.weeks(containing: displayedMonth) }
    private var selectedKey: String { DateFormatting.dayString(selectedDate) }

    var body: some View {
        // 数据变化才聚合一次，42 个格子与选中行复用同一字典
        let aggregates = aggregateCache.value(for: repository?.revision ?? 0) {
            Perf.measure("CalendarAggregate") {
                aggregateDay(logs: logEntities.map { $0.toModel() },
                             emotions: emotionEntities.map { $0.toModel() },
                             tasks: taskEntities.map { $0.toModel() })
            }
        }
        VStack(spacing: 0) {
            // 头部
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("上一月")
                    .help("上一月")
                Text(monthTitle)
                    .font(Typography.cardTitle)
                    .frame(minWidth: 140) // 月份标题最小宽度，切换月份不抖动（几何值）
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("下一月")
                    .help("下一月")
                Spacer()
                Button {
                    editingTask = nil
                    showingTaskEditor = true
                } label: {
                    Label("新建任务", systemImage: "plus")
                }
                Button("回到今天") {
                    let today = Date()
                    let order = Self.gregorian.compare(today, to: displayedMonth, toGranularity: .month)
                    monthDirection = order == .orderedAscending ? -1 : (order == .orderedDescending ? 1 : 0)
                    displayedMonth = today
                    selectedDate = today
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10) // 头部纵向内距：紧凑特调值（无对应令牌）

            // 星期表头
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 6) // 表头与网格的紧凑间距

            // 月网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.xxs), count: 7),
                      spacing: Spacing.xxs) {
                ForEach(weeks.flatMap { $0 }, id: \.self) { date in
                    dayCell(date, aggregates: aggregates)
                }
            }
            .padding(.horizontal, Spacing.md)
            .id(displayedMonth)
            .transition(monthTransition)
            .animation(reduceMotion ? Motion.reducedFade(true) : Motion.emphasize(false),
                       value: displayedMonth)

            Divider().padding(.vertical, Spacing.xs)

            // 选中日详情
            ScrollView {
                VStack(alignment: .leading, spacing: 10) { // 10：详情行的紧凑节奏（无对应令牌）
                    Text("\(selectedKey) 详情")
                        .font(Typography.cardTitle)
                    if let aggregate = aggregates[selectedKey] {
                        if aggregate.emotions.isEmpty && aggregate.logs.isEmpty && aggregate.tasks.isEmpty {
                            Text("这一天没有记录").foregroundStyle(.secondary)
                        }
                        ForEach(aggregate.tasks) { task in
                            taskRow(task)
                        }
                        ForEach(aggregate.emotions) { emotion in
                            Label("\(emotion.level.emoji) \(emotion.level.displayName)",
                                  systemImage: "face.smiling")
                                .font(Typography.secondary)
                        }
                        ForEach(aggregate.logs) { log in
                            LogCardView(log: log, onToggleFavorite: { toggleFavorite(log) })
                        }
                    } else {
                        Text("这一天没有记录").foregroundStyle(.secondary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            TaskEditorView(selectedDate: selectedDate, task: editingTask) { task in
                save(task, warnPastReminder: true)
            }
        }
        // 跨模块定位（全局搜索跳到任务）：消费一次 focusTarget，选中并翻到任务所在日期。
        // onAppear 兜底：跨模块切换使本视图首次创建时 token 已递增，onChange 不会回放。
        .onAppear { flushFocusTarget() }
        .onChange(of: appState.focusRequestToken) { flushFocusTarget() }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var monthTitle: String {
        DateFormatting.monthTitle(displayedMonth)
    }

    /// 月份切换过渡：方向性水平滑移（前进自右入/向左出，后退反之）+ 淡入淡出；
    /// 无方向（回到本月）退化为轻上移；Reduce Motion 仅淡入淡出。
    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        guard monthDirection != 0 else { return .appear(reduceMotion: false) }
        let x: CGFloat = monthDirection > 0 ? 14 : -14
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: x)),
            removal: .opacity.combined(with: .offset(x: -x))
        )
    }

    private func shiftMonth(_ delta: Int) {
        monthDirection = delta < 0 ? -1 : 1
        displayedMonth = Self.gregorian.date(byAdding: .month, value: delta, to: displayedMonth)!
    }

    /// 消费跨模块定位：任务搜索结果 → 选中其日历日并跟随翻月；无日期载荷时仅切页不动作
    private func flushFocusTarget() {
        guard let target = appState.consumeFocusTarget(),
              let day = target.taskDate,
              let date = DateFormatting.parseDay(day) else { return }
        let order = Self.gregorian.compare(date, to: displayedMonth, toGranularity: .month)
        monthDirection = order == .orderedAscending ? -1 : (order == .orderedDescending ? 1 : 0)
        displayedMonth = date
        selectedDate = date
    }

    private func dayCell(_ date: Date, aggregates: [String: DayAggregate]) -> some View {
        let key = DateFormatting.dayString(date)
        let inMonth = DateFormatting.monthString(date) == DateFormatting.monthString(displayedMonth)
        let aggregate = aggregates[key]

        return DayCell(
            day: Self.gregorian.component(.day, from: date),
            key: key,
            inMonth: inMonth,
            isToday: key == DateFormatting.today(),
            isSelected: key == selectedKey,
            logCount: aggregate?.logs.count ?? 0,
            taskCount: aggregate?.tasks.count ?? 0,
            emotionEmoji: aggregate?.emotions.first?.level.emoji,
            emotionCount: aggregate?.emotions.count ?? 0,
            reduceMotion: reduceMotion
        ) {
            selectedDate = date
            // 选中溢出天时跟随切换月份（对齐 Android selectDate）
            if !inMonth {
                let order = Self.gregorian.compare(date, to: displayedMonth, toGranularity: .month)
                monthDirection = order == .orderedAscending ? -1 : 1
                displayedMonth = date
            }
        }
    }

    @ViewBuilder private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) { // 10：勾选钮与标题的紧凑节奏（无对应令牌）
            Button {
                var updated = task
                // 与 TaskEditorView 一致使用带毫秒的 ISO-8601：同秒内「创建+完成」
                // 时无毫秒格式会产生 updatedAt < createdAt 的非法任务（导入被跳过、导出失败）
                let now = DateFormatting.isoNow()
                updated.completedAt = task.isCompleted ? nil : now
                updated.updatedAt = now
                save(updated)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为完成")
            .help(task.isCompleted ? "标记为未完成" : "标记为完成")
            VStack(alignment: .leading, spacing: 2) { // 2：标题与备注的极小间距
                Text(task.title).strikethrough(task.isCompleted)
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes).font(Typography.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                // Idea→Task 来源关联：跳回记录页并打开该灵感的编辑弹层
                if let sourceLogId = task.sourceLogId {
                    Button {
                        appState.requestFocus(.log(sourceLogId))
                    } label: {
                        Label("查看灵感", systemImage: "lightbulb")
                            .font(Typography.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColors.ideaYellowText)
                    .help("跳转到来源灵感")
                }
            }
            Spacer()
            Button("编辑") { editingTask = task; showingTaskEditor = true }
            Button(role: .destructive) { delete(task) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .accessibilityLabel("删除任务")
                .help("删除任务")
        }
        .padding(10) // 行内边距：紧凑特调值（无对应令牌）
        .background(BrandColors.weakSurface, in: RoundedRectangle(cornerRadius: Radius.row))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.row)
                .strokeBorder(BrandColors.weakBorder, lineWidth: 0.5)
        }
    }

    /// 保存任务并重建系统提醒。warnPastReminder 仅编辑器保存路径传 true：
    /// 提醒时间已过会被 TaskReminderScheduler 静默跳过，必须让用户看见；
    /// 勾选完成等高频路径不打扰。
    private func save(_ task: TaskItem, warnPastReminder: Bool = false) {
        do {
            guard let repository else { throw CalendarDataError.repositoryUnavailable }
            try repository.saveTask(task)
            showingTaskEditor = false
            Task {
                do {
                    try await TaskReminderScheduler.shared.schedule(task)
                    if warnPastReminder, TaskReminderScheduler.hasPastReminder(task) {
                        message = "任务已保存，但提醒时间已过，将不会提醒"
                    }
                } catch {
                    message = "任务已保存，但系统提醒未启用"
                }
            }
        } catch {
            message = "任务保存失败，请重试"
        }
    }

    private func delete(_ task: TaskItem) {
        do {
            guard let repository else { throw CalendarDataError.repositoryUnavailable }
            try repository.deleteTask(id: task.id)
            Task { await TaskReminderScheduler.shared.cancel(task.id) }
        } catch {
            message = "任务删除失败，请重试"
        }
    }

    private func toggleFavorite(_ log: LogItem) {
        do { try repository?.setLogFavorite(id: log.id, !(log.isFavorite ?? false)) }
        catch {
            print("[CalendarView] 收藏切换失败: \(error)")
            message = "操作失败，请重试"
        }
    }

    private enum CalendarDataError: Error {
        case repositoryUnavailable
    }
}

/// 日历单格：选中态 / 今天高亮 / hover 微反馈，状态变化统一走 Motion.quick。
/// hover 状态下沉到格子内部，避免整页 body（含 aggregates）因 hover 重算。
private struct DayCell: View {
    let day: Int
    let key: String
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let logCount: Int
    let taskCount: Int
    let emotionEmoji: String?
    let emotionCount: Int
    let reduceMotion: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) { // 2：日期数字与指示点的极小间距
                Text("\(day)")
                    .font(Typography.secondary)
                    .foregroundStyle(isSelected ? Color.white
                                     : (inMonth ? Color.primary : Color.secondary.opacity(0.5)))
                HStack(spacing: 3) { // 3：指示标记的极小间距
                    if logCount > 0 {
                        Text("\(logCount)")
                            .font(Typography.fine)
                            .foregroundStyle(isSelected ? Color.white : BrandColors.accent)
                    }
                    if taskCount > 0 {
                        Label("\(taskCount)", systemImage: "checklist")
                            .labelStyle(.titleAndIcon)
                            .font(Typography.fine)
                            .foregroundStyle(isSelected ? Color.white : BrandColors.accessibleGreen)
                    }
                    if let emotionEmoji {
                        Text(emotionEmoji).font(Typography.fine)
                    }
                }
                .frame(height: 14) // 指示行固定高度，保证无记录日格子等高（几何值）
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTouchTarget)
            .background {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor)
                                    : Color.primary.opacity(hovering ? 0.05 : 0))
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .stroke(BrandColors.accent, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick(reduceMotion), value: hovering)
        .animation(Motion.quick(reduceMotion), value: isSelected)
        .accessibilityLabel(key)
        .accessibilityValue("\(logCount) 条记录，\(emotionCount) 次情绪，\(taskCount) 项任务")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
