// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum TaskDueKind: String, Codable, Sendable {
    case allDay
    case dateTime
}

/// flash-backup-v2 的跨端任务模型。日期时间一律存 UTC ISO-8601，展示日期由 IANA 时区计算。
public struct TaskItem: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var notes: String?
    public var colorTag: ColorTag
    public var importance: Int
    public var dueKind: TaskDueKind
    public var dueDate: String?
    public var dueAt: String?
    public var timeZone: String?
    public var reminderAt: String?
    public var completedAt: String?
    /// Idea→Task 来源关联：指向 logs 分区的一条记录 ID（备份分区 schema 2，可空）
    public var sourceLogId: String? = nil
    /// 收藏（备份分区 schema 2，可空）
    public var isFavorite: Bool? = nil
    public var createdAt: String
    public var updatedAt: String

    public var isCompleted: Bool { completedAt != nil }

    public var calendarDate: String? {
        switch dueKind {
        case .allDay:
            return dueDate
        case .dateTime:
            guard let dueAt,
                  let timeZone,
                  let zone = TimeZone(identifier: timeZone),
                  let date = TaskItem.parseFraction(dueAt) ?? TaskItem.parseWholeSecond(dueAt) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return nil
            }
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    // 共享 ISO8601DateFormatter 经串行队列访问（安全审计项）；nonisolated(unsafe) 仅为编译期标注
    private static let isoQueue = DispatchQueue(label: "com.flash.app.task-item.iso")
    nonisolated(unsafe) private static let isoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let isoWholeSecond: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseFraction(_ string: String) -> Date? {
        isoQueue.sync { isoFraction.date(from: string) }
    }

    private static func parseWholeSecond(_ string: String) -> Date? {
        isoQueue.sync { isoWholeSecond.date(from: string) }
    }

    public init(id: String, title: String, notes: String? = nil, colorTag: ColorTag, importance: Int, dueKind: TaskDueKind, dueDate: String? = nil, dueAt: String? = nil, timeZone: String? = nil, reminderAt: String? = nil, completedAt: String? = nil, sourceLogId: String? = nil, isFavorite: Bool? = nil, createdAt: String, updatedAt: String) {
        self.id = id
        self.title = title
        self.notes = notes
        self.colorTag = colorTag
        self.importance = importance
        self.dueKind = dueKind
        self.dueDate = dueDate
        self.dueAt = dueAt
        self.timeZone = timeZone
        self.reminderAt = reminderAt
        self.completedAt = completedAt
        self.sourceLogId = sourceLogId
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
