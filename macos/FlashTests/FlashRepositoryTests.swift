// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import SwiftData
@testable import Flash

@Suite("FlashRepository") @MainActor
struct FlashRepositoryTests {
    private func makeRepo(beforeSave: @escaping () throws -> Void = {}) -> FlashRepository {
        FlashRepository(container: FlashDatabase.makeContainer(inMemory: true), beforeSave: beforeSave)
    }

    @Test func addLogAssignsFields() throws {
        let repo = makeRepo()
        try repo.addLog(content: "第一条", colorTag: .daily)
        let logs = try repo.allLogs()
        #expect(logs.count == 1)
        #expect(logs[0].content == "第一条")
        #expect(logs[0].colorTag == .daily)
        #expect(logs[0].category == .log)
        #expect(logs[0].importance == 0)
        #expect(logs[0].recordDate == DateFormatting.today())
        #expect(logs[0].id.count == 36) // UUID
    }

    @Test func importanceCoerced() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .idea, category: .idea, importance: 99)
        #expect(try repo.allLogs()[0].importance == 4)
    }

    @Test func updateAndDeleteLog() throws {
        let repo = makeRepo()
        try repo.addLog(content: "旧", colorTag: .memo)
        var log = try repo.allLogs()[0]
        log.content = "新"
        log.colorTag = .urgent
        try repo.updateLog(log)
        #expect(try repo.allLogs()[0].content == "新")
        #expect(try repo.allLogs()[0].colorTag == .urgent)
        try repo.deleteLog(id: log.id)
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func addAndDeleteEmotion() throws {
        let repo = makeRepo()
        try repo.addEmotion(level: .unhappy, subEmotion: .sad, note: "下雨")
        let emotions = try repo.allEmotions()
        #expect(emotions.count == 1)
        #expect(emotions[0].level == .unhappy)
        #expect(emotions[0].subEmotion == .sad)
        #expect(emotions[0].note == "下雨")
        try repo.deleteEmotion(id: emotions[0].id)
        #expect(try repo.allEmotions().isEmpty)
    }

    @Test func logsSortedNewestFirst() throws {
        let repo = makeRepo()
        // 固定且互不相同的 createdAt，避免同毫秒并列导致排序不稳定
        let oldest = LogItem(id: "11111111-1111-1111-1111-111111111111", content: "A",
                             colorTag: .daily, category: .log, importance: 0,
                             createdAt: "2026-08-10T01:00:00.000Z", recordDate: "2026-08-10")
        let middle = LogItem(id: "22222222-2222-2222-2222-222222222222", content: "B",
                             colorTag: .daily, category: .log, importance: 0,
                             createdAt: "2026-08-10T02:00:00.000Z", recordDate: "2026-08-10")
        let newest = LogItem(id: "33333333-3333-3333-3333-333333333333", content: "C",
                             colorTag: .daily, category: .log, importance: 0,
                             createdAt: "2026-08-10T03:00:00.000Z", recordDate: "2026-08-10")
        try repo.mergeAll(logs: [oldest, middle, newest], emotions: [])
        let logs = try repo.allLogs()
        #expect(logs.map(\.createdAt) == ["2026-08-10T03:00:00.000Z",
                                          "2026-08-10T02:00:00.000Z",
                                          "2026-08-10T01:00:00.000Z"]) // createdAt 严格降序
    }

    @Test func mergeAllOverwritesSameId() throws {
        let repo = makeRepo()
        try repo.addLog(content: "保留", colorTag: .daily)
        let existing = try repo.allLogs()[0]
        let incoming = LogItem(id: existing.id, content: "覆盖", colorTag: .urgent,
                               category: .log, importance: 2,
                               createdAt: existing.createdAt, recordDate: existing.recordDate)
        let fresh = LogItem(id: "11111111-1111-1111-1111-111111111111", content: "新增",
                            colorTag: .memo, category: .log, importance: 0,
                            createdAt: existing.createdAt, recordDate: existing.recordDate)
        try repo.mergeAll(logs: [incoming, fresh], emotions: [])
        let logs = try repo.allLogs()
        #expect(logs.count == 2)
        #expect(logs.contains { $0.id == existing.id && $0.content == "覆盖" })
    }

    @Test func replaceAllClearsFirst() throws {
        let repo = makeRepo()
        try repo.addLog(content: "被清掉", colorTag: .daily)
        try repo.replaceAll(logs: [], emotions: [])
        #expect(try repo.allLogs().isEmpty)
    }

    @Test func clearAllWorks() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .daily)
        try repo.addEmotion(level: .happy, subEmotion: nil)
        try repo.clearAll()
        #expect(try repo.allLogs().isEmpty)
        #expect(try repo.allEmotions().isEmpty)
    }

    @Test func snapshotContainsEveryPortableSection() throws {
        let repo = makeRepo()
        try repo.addLog(content: "x", colorTag: .daily)
        try repo.addEmotion(level: .happy, subEmotion: nil)
        try repo.saveTask(task(title: "任务", updatedAt: "2026-08-31T01:00:00.000Z"))

        let snapshot = try repo.snapshot()

        #expect(snapshot.logs.count == 1)
        #expect(snapshot.emotions.count == 1)
        #expect(snapshot.tasks.count == 1)
    }

    @Test func failedMutationsRollbackAndNeverLeakIntoLaterSave() throws {
        var failNextSave = false
        let repo = makeRepo {
            if failNextSave {
                failNextSave = false
                throw InjectedSaveError.failed
            }
        }
        try repo.addLog(content: "保留", colorTag: .daily)
        let original = try repo.snapshot()
        let incoming = LogItem(
            id: "11111111-1111-1111-1111-111111111111",
            content: "不应提交",
            colorTag: .urgent,
            category: .log,
            importance: 1,
            createdAt: "2026-09-05T00:00:00.000Z",
            recordDate: "2026-09-05"
        )

        failNextSave = true
        #expect(throws: InjectedSaveError.self) {
            try repo.replaceAll(logs: [incoming], emotions: [])
        }
        #expect(try repo.snapshot().logs == original.logs)

        failNextSave = true
        #expect(throws: InjectedSaveError.self) {
            try repo.mergeAll(logs: [incoming], emotions: [])
        }
        #expect(try repo.snapshot().logs == original.logs)

        failNextSave = true
        #expect(throws: InjectedSaveError.self) {
            try repo.clearAll()
        }
        #expect(try repo.snapshot().logs == original.logs)

        // A later successful save must not carry any pending delete or insert
        // from the three failed operations.
        try repo.addEmotion(level: .happy, subEmotion: nil)
        let final = try repo.snapshot()
        #expect(final.logs == original.logs)
        #expect(final.emotions.count == 1)
        #expect(!final.logs.contains { $0.id == incoming.id })
    }

    private enum InjectedSaveError: Error {
        case failed
    }

    @Test func taskMergeUsesNewestUpdatedAt() throws {
        let repo = makeRepo()
        let newer = task(title: "新", updatedAt: "2026-08-31T02:00:00.000Z")
        let older = task(title: "旧", updatedAt: "2026-08-31T01:00:00.000Z")

        try repo.mergeAll(logs: [], emotions: [], tasks: [newer])
        try repo.mergeAll(logs: [], emotions: [], tasks: [older])

        #expect(try repo.allTasks().map(\.title) == ["新"])
    }

    private func task(title: String, updatedAt: String) -> TaskItem {
        TaskItem(
            id: "33333333-3333-3333-3333-333333333333",
            title: title,
            notes: nil,
            colorTag: .memo,
            importance: 0,
            dueKind: .allDay,
            dueDate: "2026-09-01",
            dueAt: nil,
            timeZone: nil,
            reminderAt: nil,
            completedAt: nil,
            createdAt: "2026-08-31T00:00:00.000Z",
            updatedAt: updatedAt
        )
    }
}
