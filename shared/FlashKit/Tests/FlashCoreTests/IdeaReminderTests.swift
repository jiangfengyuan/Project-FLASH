// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
@testable import FlashCore

@Suite("灵感提醒")
struct IdeaReminderTests {
    private func idea(_ id: String, _ createdAt: String, category: FlashCore.Category = .idea) -> LogItem {
        LogItem(id: id, content: id, colorTag: .idea, category: category, importance: 0,
                createdAt: createdAt, recordDate: String(createdAt.prefix(10)))
    }

    private var shanghai: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return formatter.date(from: text)!
    }

    @Test func unreadIsUnviewedIdeasNewestFirst() {
        let logs = [idea("a", "2026-10-20T08:00:00.000Z"),
                    idea("b", "2026-10-22T08:00:00.000Z"),
                    idea("c", "2026-10-21T08:00:00.000Z"),
                    idea("log", "2026-10-23T08:00:00.000Z", category: .log)]
        let unread = IdeaReminder.unreadIdeas(in: logs, viewed: ["c"])
        #expect(unread.map(\.id) == ["b", "a"])
    }

    @Test func thresholdIsThree() {
        #expect(!IdeaReminder.shouldRemind(unreadCount: 2))
        #expect(IdeaReminder.shouldRemind(unreadCount: 3))
        #expect(IdeaReminder.notificationBody(unreadCount: 5) == "你还有5个想法等待梳理，去看看吧")
    }

    @Test func dailyFiresTonightOrTomorrow() {
        let calendar = shanghai
        #expect(IdeaReminder.nextFireDate(now: date("2026-10-23T09:00:00"), lastFired: nil,
                                          frequency: .daily, calendar: calendar) == date("2026-10-23T20:00:00"))
        #expect(IdeaReminder.nextFireDate(now: date("2026-10-23T21:00:00"), lastFired: nil,
                                          frequency: .daily, calendar: calendar) == date("2026-10-24T20:00:00"))
    }

    @Test func frequencyCountsFromLastReminder() {
        let calendar = shanghai
        let last = date("2026-10-20T20:00:00")
        #expect(IdeaReminder.nextFireDate(now: date("2026-10-21T09:00:00"), lastFired: last,
                                          frequency: .every3Days, calendar: calendar) == date("2026-10-23T20:00:00"))
        #expect(IdeaReminder.nextFireDate(now: date("2026-10-21T09:00:00"), lastFired: last,
                                          frequency: .weekly, calendar: calendar) == date("2026-10-27T20:00:00"))
        // 早已过了间隔：取 now 之后最近的 20:00
        #expect(IdeaReminder.nextFireDate(now: date("2026-11-05T21:00:00"), lastFired: last,
                                          frequency: .weekly, calendar: calendar) == date("2026-11-06T20:00:00"))
    }

    @Test func storeBaselineMarksExistingIdeasViewedAndPersists() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = IdeaViewStateStore(directory: directory)
        #expect(!store.hasBaseline)
        store.establishBaselineIfNeeded(existingIdeaIDs: ["old1", "old2"])
        store.establishBaselineIfNeeded(existingIdeaIDs: ["new"]) // 基线只建立一次
        store.markViewed("x")
        #expect(store.viewedIDs == ["old1", "old2", "x"])

        let reloaded = IdeaViewStateStore(directory: directory)
        #expect(reloaded.hasBaseline)
        #expect(reloaded.viewedIDs == ["old1", "old2", "x"])
        reloaded.prune(keeping: ["old1", "x"])
        #expect(IdeaViewStateStore(directory: directory).viewedIDs == ["old1", "x"])
    }

    @Test func corruptFileFallsBackToFreshBaseline() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("idea-view-state.json"))
        let store = IdeaViewStateStore(directory: directory)
        #expect(!store.hasBaseline)
        #expect(store.viewedIDs.isEmpty)
    }

    @Test @MainActor func repositoryListsIdeasOnly() throws {
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        try repository.addLog(content: "日志", colorTag: .daily, category: .log)
        try repository.addLog(content: "灵感", colorTag: .idea, category: .idea)
        #expect(try repository.allIdeas().map(\.content) == ["灵感"])
    }

    @Test func ideaReminderSettingsDefaultOnDaily() {
        let defaults = UserDefaults(suiteName: "idea-reminder-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.ideaReminderEnabled)
        #expect(settings.ideaReminderFrequency == .daily)
        settings.setIdeaReminderEnabled(false)
        settings.setIdeaReminderFrequency(.weekly)
        let reloaded = SettingsStore(defaults: defaults)
        #expect(!reloaded.ideaReminderEnabled)
        #expect(reloaded.ideaReminderFrequency == .weekly)
    }
}
