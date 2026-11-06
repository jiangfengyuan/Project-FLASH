// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

@Suite("任务提醒通知操作")
struct TaskReminderActionsTests {
    private func task() -> TaskItem {
        TaskItem(id: "t1", title: "交周报", notes: nil, colorTag: .memo, importance: 0,
                 dueKind: .dateTime, dueDate: nil, dueAt: "2026-10-23T12:00:00.000Z",
                 timeZone: "Asia/Shanghai", reminderAt: "2026-10-23T11:45:00.000Z",
                 completedAt: nil, createdAt: "2026-10-20T00:00:00.000Z", updatedAt: "2026-10-20T00:00:00.000Z")
    }

    private let now = ISO8601DateFormatter().date(from: "2026-10-23T11:45:00Z")!

    @Test func completeMarksDoneAndBumpsUpdatedAt() {
        let done = TaskReminderActions.completed(task(), now: now)
        #expect(done.isCompleted)
        #expect(done.completedAt == "2026-10-23T11:45:00.000Z")
        #expect(done.updatedAt == "2026-10-23T11:45:00.000Z")
        #expect(done.dueAt == task().dueAt)
    }

    @Test func snoozeMovesReminderTenMinutesOnly() {
        let later = TaskReminderActions.snoozed(task(), now: now)
        #expect(later.reminderAt == "2026-10-23T11:55:00.000Z")
        #expect(later.dueAt == task().dueAt)
        #expect(!later.isCompleted)
    }
}
