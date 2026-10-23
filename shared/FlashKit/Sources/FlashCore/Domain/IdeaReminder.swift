// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 灵感提醒（PRD v3 §6.3）：从未打开查看过的灵感累计 ≥ 3 条时提醒梳理。
/// 阈值与「未读」口径与 Android（domain/IdeaReminder.kt）、HarmonyOS（data/IdeaReminder.ets）一致。
public enum IdeaReminder {
    public static let threshold = 3

    /// 推送频率（PRD：每天 / 每 3 天 / 每周，默认每天）
    public enum Frequency: String, CaseIterable, Sendable {
        case daily, every3Days, weekly

        public var displayName: String {
            switch self {
            case .daily: "每天"
            case .every3Days: "每 3 天"
            case .weekly: "每周"
            }
        }

        public var intervalDays: Int {
            switch self {
            case .daily: 1
            case .every3Days: 3
            case .weekly: 7
            }
        }
    }

    /// 未读灵感：category = idea 且不在已读集合中，按创建时间倒序（最新在前）
    public static func unreadIdeas(in logs: [LogItem], viewed: Set<String>) -> [LogItem] {
        logs.filter { $0.category == .idea && !viewed.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public static func shouldRemind(unreadCount: Int) -> Bool {
        unreadCount >= threshold
    }

    /// 通知正文（PRD 文案）
    public static func notificationBody(unreadCount: Int) -> String {
        "你还有\(unreadCount)个想法等待梳理，去看看吧"
    }

    /// 下一次提醒时刻：不早于 now 之后的第一个 hour:00；若上次已提醒，还需与上次间隔满 frequency 天。
    /// 间隔按日历日计算（每 3 天 = 上次提醒日 + 3 天的 hour:00），跨时区与夏令时由 calendar 处理。
    public static func nextFireDate(now: Date, lastFired: Date?, frequency: Frequency,
                                    hour: Int = 20, calendar: Calendar = .current) -> Date {
        let todayAtHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
        var candidate = todayAtHour > now ? todayAtHour : calendar.date(byAdding: .day, value: 1, to: todayAtHour)!
        if let lastFired {
            let lastDayAtHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: lastFired)!
            let earliest = calendar.date(byAdding: .day, value: frequency.intervalDays, to: lastDayAtHour)!
            if earliest > candidate { candidate = earliest }
        }
        return candidate
    }
}
