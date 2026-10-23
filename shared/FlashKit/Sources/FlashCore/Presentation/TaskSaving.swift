// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 任务保存契约（此刻「+ 新建任务」、记录页「灵感转任务」、日历页共用）：
/// 先入库，再异步安排系统提醒；提醒失败不影响已入库的任务，只回一条提示文案。
public enum TaskSaving {
    /// 安排（或取消）该任务的系统提醒。返回需告知用户的提示；nil 表示无需提示
    public static func scheduleReminder(for task: TaskItem) async -> String? {
        do {
            try await TaskReminderScheduler.shared.schedule(task)
            return TaskReminderScheduler.hasPastReminder(task) ? "任务已保存，但提醒时间已过，将不会提醒" : nil
        } catch {
            return "任务已保存，但系统提醒未启用"
        }
    }
}
