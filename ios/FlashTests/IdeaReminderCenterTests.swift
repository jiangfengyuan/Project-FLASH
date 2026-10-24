// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Testing
import FlashCore
@testable import Flash

@MainActor
@Suite("iOS 灵感提醒装配")
struct IdeaReminderCenterTests {
    /// 推送关闭：只验证角标 / 提示行逻辑，不触达系统通知权限
    private func makeSettings() -> SettingsStore {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "reminder-\(UUID().uuidString)")!)
        settings.setIdeaReminderEnabled(false)
        return settings
    }

    @Test func existingIdeasAreBaselineAndNewOnesCountTowardThreshold() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        let settings = makeSettings()
        try repository.addLog(content: "历史灵感", colorTag: .idea, category: .idea)

        let center = IdeaReminderCenter(store: IdeaViewStateStore(directory: directory))
        center.refresh(repository: repository, settings: settings)
        #expect(center.unreadCount == 0)          // 基线：历史灵感视为已读

        for text in ["一", "二", "三"] {
            try repository.addLog(content: text, colorTag: .idea, category: .idea)
        }
        try repository.addLog(content: "日志不计", colorTag: .daily, category: .log)
        center.refresh(repository: repository, settings: settings)
        #expect(center.unreadCount == 3)
        #expect(center.shouldRemind)
        #expect(center.badgeCount == 3)
        #expect(center.oldestUnread?.content == "一")

        let oldest = try #require(center.oldestUnread)
        center.markViewed(oldest.id, repository: repository, settings: settings)
        #expect(center.unreadCount == 2)
        #expect(!center.shouldRemind)
        #expect(center.badgeCount == 0)
    }

    @Test func deletingAnIdeaPrunesItsReadState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FlashRepository(container: FlashDatabase.makeContainer(inMemory: true))
        let settings = makeSettings()
        let store = IdeaViewStateStore(directory: directory)
        let center = IdeaReminderCenter(store: store)
        center.refresh(repository: repository, settings: settings)
        try repository.addLog(content: "看过就删", colorTag: .idea, category: .idea)
        center.refresh(repository: repository, settings: settings)
        let idea = try #require(center.oldestUnread)
        center.markViewed(idea.id, repository: repository, settings: settings)
        #expect(store.viewedIDs.contains(idea.id))
        try repository.deleteLog(id: idea.id)
        center.refresh(repository: repository, settings: settings)
        #expect(!store.viewedIDs.contains(idea.id))
    }
}
