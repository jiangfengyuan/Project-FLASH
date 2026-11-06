// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 任务提醒通知上的「完成 / 稍后」操作：纯数据变换 + 仓储写入，平台只负责转发通知响应。
public enum TaskReminderActions {
    /// 标记完成：写 completedAt / updatedAt
    public static func completed(_ task: TaskItem, now: Date = Date()) -> TaskItem {
        var task = task
        let stamp = isoString(now)
        task.completedAt = stamp
        task.updatedAt = stamp
        return task
    }

    /// 稍后提醒：提醒时间改为 now + minutes（任务截止时间不变）
    public static func snoozed(_ task: TaskItem, minutes: Int = TaskReminderScheduler.snoozeMinutes,
                               now: Date = Date()) -> TaskItem {
        var task = task
        task.reminderAt = isoString(now.addingTimeInterval(TimeInterval(minutes * 60)))
        task.updatedAt = isoString(now)
        return task
    }

    /// 执行通知操作：找到任务、写库、重排（完成 → 撤销提醒；稍后 → 重新安排）。任务已删除时忽略
    @MainActor
    public static func perform(actionIdentifier: String, taskID: String,
                               repository: FlashRepository) async {
        guard let task = try? repository.tasksOnly().first(where: { $0.id == taskID }) else { return }
        let updated: TaskItem
        switch actionIdentifier {
        case TaskReminderScheduler.completeActionIdentifier: updated = completed(task)
        case TaskReminderScheduler.snoozeActionIdentifier: updated = snoozed(task)
        default: return
        }
        do {
            try repository.saveTask(updated)
            // schedule 对已完成任务会撤销提醒，对稍后的任务按新时间重排
            try await TaskReminderScheduler.shared.schedule(updated)
        } catch {
            print("TaskReminderActions: 处理通知操作失败 - \(error)")
        }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
