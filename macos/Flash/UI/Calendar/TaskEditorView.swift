import SwiftUI

/// Idea→Task 转化草稿（PRD §18）：灵感内容预填为任务标题，sourceLogId 回写任务来源关联；
/// 原灵感保留不动。Identifiable 供 .sheet(item:) 承载。
struct IdeaTaskDraft: Identifiable, Equatable {
    /// 来源灵感 id（写入 TaskItem.sourceLogId）
    let sourceLogId: String
    /// 预填标题（灵感内容）
    let title: String
    var id: String { sourceLogId }
}

struct TaskEditorView: View {
    let selectedDate: Date
    let task: TaskItem?
    /// 任务来源：编辑既有任务取 task.sourceLogId；Idea→Task 新建由 ideaDraft 带入
    private let sourceLogId: String?
    let onSave: (TaskItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var allDay: Bool
    @State private var dueDate: Date
    @State private var reminderMinutes: Int?
    @State private var isFavorite: Bool

    private var editorTimeZone: TimeZone {
        task?.timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    init(selectedDate: Date, task: TaskItem?, ideaDraft: IdeaTaskDraft? = nil,
         onSave: @escaping (TaskItem) -> Void) {
        self.selectedDate = selectedDate
        self.task = task
        self.sourceLogId = task?.sourceLogId ?? ideaDraft?.sourceLogId
        self.onSave = onSave
        let initialDate = task.flatMap(Self.dateForTask) ?? selectedDate
        _title = State(initialValue: task?.title ?? ideaDraft?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _allDay = State(initialValue: task?.dueKind != .dateTime)
        _dueDate = State(initialValue: initialDate)
        _reminderMinutes = State(initialValue: Self.reminderOffset(task: task, dueDate: initialDate))
        _isFavorite = State(initialValue: task?.isFavorite ?? false)
    }

    /// 契约上限（UTF-16 单元，见 TextLimits）：超限禁用保存并提示，不静默截断
    private var titleExceedsLimit: Bool { !TextLimits.fits(title, limit: TextLimits.maxTaskTitleUTF16) }
    private var notesExceedsLimit: Bool { !TextLimits.fits(notes) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(task == nil ? "新建任务" : "编辑任务").font(Typography.sectionTitle)
            // Idea→Task 来源关联（只读）：新建由 ideaDraft 带入，编辑既有任务时同样可见
            if sourceLogId != nil {
                Label("来源：灵感", systemImage: "lightbulb")
                    .font(Typography.caption)
                    .foregroundStyle(BrandColors.ideaYellowText)
                    .accessibilityLabel("此任务由灵感转化而来")
            }
            TextField("任务标题", text: $title).textFieldStyle(.roundedBorder)
            if titleExceedsLimit {
                Text("标题超出上限（\(title.utf16.count)/\(TextLimits.maxTaskTitleUTF16)）")
                    .font(Typography.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            TextField("备注（可选）", text: $notes, axis: .vertical).lineLimit(2...5)
            if notesExceedsLimit {
                Text("备注超出上限（\(notes.utf16.count)/\(TextLimits.maxContentUTF16)）")
                    .font(Typography.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            Toggle("全天任务", isOn: $allDay)
            Toggle("收藏", isOn: $isFavorite)
            DatePicker("截止时间", selection: $dueDate,
                       displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
            Picker("本地提醒", selection: $reminderMinutes) {
                Text("不提醒").tag(Int?.none)
                Text("截止时").tag(Int?.some(0))
                Text("提前 15 分钟").tag(Int?.some(15))
                Text("提前 1 小时").tag(Int?.some(60))
                Text("提前 1 天").tag(Int?.some(1440))
            }
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") { onSave(makeTask()) }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || titleExceedsLimit || notesExceedsLimit)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 430) // 编辑器固有宽度（几何值）
        .environment(\.timeZone, editorTimeZone)
    }

    private func makeTask() -> TaskItem {
        let now = Self.isoFractionString(from: Date())
        let anchor: Date
        if allDay {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = 9
            anchor = Calendar.current.date(from: components) ?? dueDate
        } else {
            anchor = dueDate
        }
        return TaskItem(
            id: task?.id ?? UUID().uuidString,
            // 保存按钮已在标题超限时禁用，此处不再截断（契约按 UTF-16 单元计）
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            colorTag: task?.colorTag ?? .memo,
            importance: task?.importance ?? 0,
            dueKind: allDay ? .allDay : .dateTime,
            dueDate: allDay ? DateFormatting.dayString(dueDate) : nil,
            dueAt: allDay ? nil : Self.isoFractionString(from: dueDate),
            timeZone: allDay ? nil : editorTimeZone.identifier,
            reminderAt: reminderMinutes.map { Self.isoFractionString(from: anchor.addingTimeInterval(-Double($0 * 60))) },
            completedAt: task?.completedAt,
            sourceLogId: sourceLogId,
            isFavorite: isFavorite,
            createdAt: task?.createdAt ?? now,
            updatedAt: now
        )
    }

    private static func dateForTask(_ task: TaskItem) -> Date? {
        if task.dueKind == .allDay, let day = task.dueDate { return DateFormatting.parseDay(day) }
        return task.dueAt.flatMap { parseISO($0) }
    }

    private static func reminderOffset(task: TaskItem?, dueDate: Date) -> Int? {
        guard let task, let reminder = task.reminderAt.flatMap({ parseISO($0) }) else {
            return nil
        }
        let anchor: Date
        if task.dueKind == .allDay {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = 9
            anchor = Calendar.current.date(from: components) ?? dueDate
        } else {
            anchor = dueDate
        }
        let minutes = Int(anchor.timeIntervalSince(reminder) / 60)
        return [0, 15, 60, 1440].contains(minutes) ? minutes : nil
    }

    // 共享 ISO8601DateFormatter 经串行队列访问（安全审计项）；nonisolated(unsafe) 仅为编译期标注
    private static let isoQueue = DispatchQueue(label: "com.flash.app.task-editor.iso")
    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return value
    }()
    nonisolated(unsafe) private static let isoWhole: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime]; return value
    }()

    private static func isoFractionString(from date: Date) -> String {
        isoQueue.sync { iso.string(from: date) }
    }

    private static func parseISO(_ string: String) -> Date? {
        isoQueue.sync { iso.date(from: string) ?? isoWhole.date(from: string) }
    }
}
