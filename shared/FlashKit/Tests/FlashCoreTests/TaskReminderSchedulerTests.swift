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

// MARK: - rebuild 与 schedule / cancel 交错（F-26）

/// 通知中心替身：可把第一次 add 挂起，模拟 rebuild 在 await 处让出 actor
private actor FakeReminderCenter: ReminderNotificationCenter {
    private(set) var pending: [String: ReminderRequest] = [:]
    private var holdFirstAdd: Bool
    private var held: CheckedContinuation<Void, Never>?
    private var heldStarted: CheckedContinuation<Void, Never>?
    private var didStartHeldAdd = false

    init(holdFirstAdd: Bool) {
        self.holdFirstAdd = holdFirstAdd
    }

    func requestAuthorization() async throws -> Bool { true }

    func add(_ request: ReminderRequest) async throws {
        if holdFirstAdd {
            holdFirstAdd = false
            didStartHeldAdd = true
            heldStarted?.resume()
            heldStarted = nil
            await withCheckedContinuation { held = $0 }
        }
        pending[request.identifier] = request
    }

    func pendingIdentifiers() async -> [String] { Array(pending.keys) }

    func removePending(withIdentifiers identifiers: [String]) async {
        for identifier in identifiers { pending[identifier] = nil }
    }

    func seed(_ request: ReminderRequest) { pending[request.identifier] = request }

    /// 等到 rebuild 进入被挂起的 add
    func waitUntilHeld() async {
        if didStartHeldAdd { return }
        await withCheckedContinuation { heldStarted = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }
}

@Suite("任务提醒重建的并发安全（F-26）")
struct TaskReminderRebuildRaceTests {
    private func task(_ id: String, title: String = "任务", completed: Bool = false) -> TaskItem {
        TaskItem(id: id, title: title, notes: nil, colorTag: .memo,
                 importance: 0, dueKind: .allDay, dueDate: "2999-01-01",
                 dueAt: nil, timeZone: nil, reminderAt: "2999-01-01T01:00:00.000Z",
                 completedAt: completed ? "2026-10-30T00:00:00.000Z" : nil,
                 createdAt: "2026-10-06T00:00:00.000Z", updatedAt: "2026-10-06T00:00:00.000Z")
    }

    private let prefix = "flash-task-reminder-"

    @Test func reminderScheduledDuringRebuildSurvivesTheStaleSweep() async throws {
        let center = FakeReminderCenter(holdFirstAdd: true)
        let scheduler = TaskReminderScheduler(center: center)
        // rebuild 的快照里只有 A（启动时读的任务表）
        let rebuild = Task { try await scheduler.rebuild([task("A")]) }
        await center.waitUntilHeld()
        // rebuild 挂起期间用户新建了带提醒的 B
        try await scheduler.schedule(task("B"))
        await center.release()
        try await rebuild.value

        let pending = Set(await center.pendingIdentifiers())
        #expect(pending == [prefix + "A", prefix + "B"])
    }

    @Test func reminderCancelledDuringRebuildIsNotResurrected() async throws {
        let center = FakeReminderCenter(holdFirstAdd: true)
        let scheduler = TaskReminderScheduler(center: center)
        // 快照里 A、C 都待提醒；第一次 add（A）被挂起
        let rebuild = Task { try await scheduler.rebuild([task("A"), task("C")]) }
        await center.waitUntilHeld()
        // 挂起期间用户完成了 C（schedule 已完成任务 = 撤销提醒）
        try await scheduler.schedule(task("C", completed: true))
        await center.release()
        try await rebuild.value

        let pending = Set(await center.pendingIdentifiers())
        #expect(pending == [prefix + "A"])
    }

    @Test func rescheduledReminderKeepsTheNewerContent() async throws {
        let center = FakeReminderCenter(holdFirstAdd: true)
        let scheduler = TaskReminderScheduler(center: center)
        let rebuild = Task { try await scheduler.rebuild([task("A"), task("B", title: "旧标题")]) }
        await center.waitUntilHeld()
        try await scheduler.schedule(task("B", title: "新标题"))
        await center.release()
        try await rebuild.value

        #expect(await center.pending[prefix + "B"]?.title == "新标题")
    }

    @Test func plainRebuildStillRemovesStaleReminders() async throws {
        let center = FakeReminderCenter(holdFirstAdd: false)
        await center.seed(ReminderRequest(identifier: prefix + "gone", taskID: "gone", title: "已删任务",
                                          fireDate: Date().addingTimeInterval(3600)))
        await center.seed(ReminderRequest(identifier: "other-app-reminder", taskID: "x", title: "x",
                                          fireDate: Date().addingTimeInterval(3600)))
        let scheduler = TaskReminderScheduler(center: center)
        try await scheduler.rebuild([task("A")])

        let pending = Set(await center.pendingIdentifiers())
        #expect(pending == [prefix + "A", "other-app-reminder"])
    }

    @Test func scheduleOutsideRebuildIsUnaffectedByEarlierRebuilds() async throws {
        let center = FakeReminderCenter(holdFirstAdd: false)
        let scheduler = TaskReminderScheduler(center: center)
        try await scheduler.rebuild([task("A")])
        try await scheduler.schedule(task("B"))
        await scheduler.cancel("A")
        // 后续一次 rebuild 只按自己的快照收敛，不受上一轮记录的影响
        try await scheduler.rebuild([task("B")])
        #expect(Set(await center.pendingIdentifiers()) == [prefix + "B"])
    }
}

// MARK: - 锁屏隐私（F-17）

@Suite("任务提醒锁屏隐私（F-17）")
struct TaskReminderPrivacyTests {
    @Test func categoryHidesTaskTitleWhenPreviewsAreHidden() {
        let category = TaskReminderScheduler.makeCategory()
        #expect(category.identifier == TaskReminderScheduler.categoryIdentifier)
        #expect(category.hiddenPreviewsBodyPlaceholder == TaskReminderScheduler.hiddenPreviewBodyPlaceholder)
        #expect(category.options.contains(.hiddenPreviewsShowTitle))
        #expect(category.actions.map(\.identifier) == [TaskReminderScheduler.completeActionIdentifier,
                                                       TaskReminderScheduler.snoozeActionIdentifier])
    }
}
