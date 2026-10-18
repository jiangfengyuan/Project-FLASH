// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

/// TaskReminderScheduler.hasPastReminder：已完成/无提醒/未来提醒/过期提醒/非法格式
struct TaskReminderSchedulerTests {

    private func task(reminderAt: String?, completedAt: String? = nil) -> TaskItem {
        TaskItem(id: UUID().uuidString, title: "任务", notes: nil, colorTag: .memo,
                 importance: 0, dueKind: .allDay, dueDate: "2026-10-06",
                 dueAt: nil, timeZone: nil, reminderAt: reminderAt, completedAt: completedAt,
                 createdAt: "2026-10-06T00:00:00.000Z", updatedAt: "2026-10-06T00:00:00.000Z")
    }

    @Test func noReminderIsNotPast() {
        #expect(TaskReminderScheduler.hasPastReminder(task(reminderAt: nil)) == false)
    }

    @Test func futureReminderIsNotPast() {
        #expect(TaskReminderScheduler.hasPastReminder(task(reminderAt: "2999-01-01T00:00:00.000Z")) == false)
    }

    @Test func pastReminderIsPast() {
        #expect(TaskReminderScheduler.hasPastReminder(task(reminderAt: "2001-01-01T00:00:00.000Z")) == true)
    }

    @Test func wholeSecondFormatParses() {
        #expect(TaskReminderScheduler.hasPastReminder(task(reminderAt: "2001-01-01T00:00:00Z")) == true)
    }

    @Test func completedTaskNeverHasPastReminder() {
        #expect(TaskReminderScheduler.hasPastReminder(
            task(reminderAt: "2001-01-01T00:00:00.000Z", completedAt: "2001-01-02T00:00:00.000Z")) == false)
    }

    @Test func malformedReminderIsNotPast() {
        #expect(TaskReminderScheduler.hasPastReminder(task(reminderAt: "not-a-date")) == false)
    }
}
