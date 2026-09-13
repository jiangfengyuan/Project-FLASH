import SwiftUI

struct TaskEditorView: View {
    let selectedDate: Date
    let task: TaskItem?
    let onSave: (TaskItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var allDay: Bool
    @State private var dueDate: Date
    @State private var reminderMinutes: Int?

    private var editorTimeZone: TimeZone {
        task?.timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    init(selectedDate: Date, task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
        self.selectedDate = selectedDate
        self.task = task
        self.onSave = onSave
        let initialDate = task.flatMap(Self.dateForTask) ?? selectedDate
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _allDay = State(initialValue: task?.dueKind != .dateTime)
        _dueDate = State(initialValue: initialDate)
        _reminderMinutes = State(initialValue: Self.reminderOffset(task: task, dueDate: initialDate))
    }

    /// 契约上限（UTF-16 单元，见 TextLimits）：超限禁用保存并提示，不静默截断
    private var titleExceedsLimit: Bool { !TextLimits.fits(title, limit: TextLimits.maxTaskTitleUTF16) }
    private var notesExceedsLimit: Bool { !TextLimits.fits(notes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task == nil ? "新建任务" : "编辑任务").font(.title2.bold())
            TextField("任务标题", text: $title).textFieldStyle(.roundedBorder)
            if titleExceedsLimit {
                Text("标题超出上限（\(title.utf16.count)/\(TextLimits.maxTaskTitleUTF16)）")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            TextField("备注（可选）", text: $notes, axis: .vertical).lineLimit(2...5)
            if notesExceedsLimit {
                Text("备注超出上限（\(notes.utf16.count)/\(TextLimits.maxContentUTF16)）")
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            Toggle("全天任务", isOn: $allDay)
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
        .padding(24)
        .frame(width: 430)
        .environment(\.timeZone, editorTimeZone)
    }

    private func makeTask() -> TaskItem {
        let now = Self.iso.string(from: Date())
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
            dueAt: allDay ? nil : Self.iso.string(from: dueDate),
            timeZone: allDay ? nil : editorTimeZone.identifier,
            reminderAt: reminderMinutes.map { Self.iso.string(from: anchor.addingTimeInterval(-Double($0 * 60))) },
            completedAt: task?.completedAt,
            createdAt: task?.createdAt ?? now,
            updatedAt: now
        )
    }

    private static func dateForTask(_ task: TaskItem) -> Date? {
        if task.dueKind == .allDay, let day = task.dueDate { return DateFormatting.parseDay(day) }
        return task.dueAt.flatMap { iso.date(from: $0) ?? isoWhole.date(from: $0) }
    }

    private static func reminderOffset(task: TaskItem?, dueDate: Date) -> Int? {
        guard let task, let reminder = task.reminderAt.flatMap({ iso.date(from: $0) ?? isoWhole.date(from: $0) }) else {
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

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return value
    }()
    nonisolated(unsafe) private static let isoWhole: ISO8601DateFormatter = {
        let value = ISO8601DateFormatter(); value.formatOptions = [.withInternetDateTime]; return value
    }()
}
