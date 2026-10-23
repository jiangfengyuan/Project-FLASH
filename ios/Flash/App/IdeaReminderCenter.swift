// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Observation
import FlashCore

/// 灵感提醒（iOS 装配）：维护未读灵感列表，驱动记录 Tab 角标、此刻提示行、卡片「未读」标记与本地通知。
/// 每次写库（仓储写代际变化）、启动与设置变更时 refresh；已读状态只在本机（IdeaViewStateStore）。
@MainActor
@Observable
final class IdeaReminderCenter {
    /// 未读灵感（最新在前）
    private(set) var unreadIdeas: [LogItem] = []

    @ObservationIgnored private let store: IdeaViewStateStore
    @ObservationIgnored private let scheduler: IdeaReminderScheduler

    init(store: IdeaViewStateStore = IdeaViewStateStore(), scheduler: IdeaReminderScheduler = .shared) {
        self.store = store
        self.scheduler = scheduler
    }

    var unreadIDs: Set<String> { Set(unreadIdeas.map(\.id)) }
    var unreadCount: Int { unreadIdeas.count }
    var shouldRemind: Bool { IdeaReminder.shouldRemind(unreadCount: unreadCount) }
    /// 记录 Tab 角标：达到阈值才显示（0 = 不显示）
    var badgeCount: Int { shouldRemind ? unreadCount : 0 }
    /// 此刻提示行点按后打开「最早的一条」（对齐 Android）
    var oldestUnread: LogItem? { unreadIdeas.last }

    /// 重新计算未读并重排通知
    func refresh(repository: FlashRepository?, settings: SettingsStore) {
        guard let repository, let ideas = try? repository.allIdeas() else { return }
        let ids = ideas.map(\.id)
        store.establishBaselineIfNeeded(existingIdeaIDs: ids)
        store.prune(keeping: Set(ids))
        unreadIdeas = IdeaReminder.unreadIdeas(in: ideas, viewed: store.viewedIDs)
        let count = unreadCount
        // 小组件快照带上未读灵感数（写库路径不知道已读状态，由这里补齐）
        WidgetSnapshot.refresh(repository: repository, unreadIdeaCount: count)
        let enabled = settings.ideaReminderEnabled
        let frequency = settings.ideaReminderFrequency
        Task { await scheduler.reschedule(unreadCount: count, enabled: enabled, frequency: frequency) }
    }

    /// 灵感被打开查看 → 已读
    func markViewed(_ id: String, repository: FlashRepository?, settings: SettingsStore) {
        guard unreadIdeas.contains(where: { $0.id == id }) else { return }
        store.markViewed(id)
        refresh(repository: repository, settings: settings)
    }
}
