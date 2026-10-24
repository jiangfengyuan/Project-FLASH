// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UserNotifications

/// 灵感提醒本地通知（PRD v3 §6.3）：未读灵感 ≥ 3 时排一条「你还有N个想法等待梳理，去看看吧」，
/// 不足 3 条或关闭开关时撤销。每次写库与启动时重排：正文计数保持最新，频率按上次提醒日起算。
/// 「每 3 天」无法用日历重复触发表达，因此始终只挂一条非重复请求，到期后下次重排时接续。
/// 权限只在确实需要排提醒时请求，不在启动时打扰。
public actor IdeaReminderScheduler {
    public static let shared = IdeaReminderScheduler()

    public static let identifier = "flash-idea-reminder"
    /// 点按通知打开的深链（记录页「灵感」筛选）
    public static let deepLink = "flash://ideas"

    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let lastScheduledKey = "ideaReminderLastScheduled"
    private let lastFiredKey = "ideaReminderLastFired"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 按当前未读数与设置重排（可频繁调用：同一时刻与正文时不重复替换）
    public func reschedule(unreadCount: Int, enabled: Bool, frequency: IdeaReminder.Frequency,
                           now: Date = Date()) async {
        // 已过的排期视为已提醒，作为频率间隔的起点
        if let scheduled = defaults.object(forKey: lastScheduledKey) as? Date, scheduled <= now {
            defaults.set(scheduled, forKey: lastFiredKey)
            defaults.removeObject(forKey: lastScheduledKey)
        }
        guard enabled, IdeaReminder.shouldRemind(unreadCount: unreadCount) else {
            cancel()
            return
        }
        let fireDate = IdeaReminder.nextFireDate(now: now,
                                                 lastFired: defaults.object(forKey: lastFiredKey) as? Date,
                                                 frequency: frequency)
        let body = IdeaReminder.notificationBody(unreadCount: unreadCount)
        if let pending = await center.pendingNotificationRequests().first(where: { $0.identifier == Self.identifier }),
           pending.content.body == body,
           (pending.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == fireDate {
            return
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "✦ Flash"
            content.body = body
            content.sound = .default
            content.threadIdentifier = Self.identifier
            content.userInfo = ["url": Self.deepLink]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(identifier: Self.identifier, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components,
                                                                                       repeats: false))
            try await center.add(request)
            defaults.set(fireDate, forKey: lastScheduledKey)
        } catch {
            print("IdeaReminderScheduler: 排提醒失败 - \(error)")
        }
    }

    public func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        defaults.removeObject(forKey: lastScheduledKey)
    }
}
