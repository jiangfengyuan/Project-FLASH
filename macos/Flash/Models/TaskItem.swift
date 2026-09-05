// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum TaskDueKind: String, Codable {
    case allDay
    case dateTime
}

/// flash-backup-v2 的跨端任务模型。日期时间一律存 UTC ISO-8601，展示日期由 IANA 时区计算。
struct TaskItem: Identifiable, Equatable {
    let id: String
    var title: String
    var notes: String?
    var colorTag: ColorTag
    var importance: Int
    var dueKind: TaskDueKind
    var dueDate: String?
    var dueAt: String?
    var timeZone: String?
    var reminderAt: String?
    var completedAt: String?
    var createdAt: String
    var updatedAt: String

    var isCompleted: Bool { completedAt != nil }

    var calendarDate: String? {
        switch dueKind {
        case .allDay:
            return dueDate
        case .dateTime:
            guard let dueAt,
                  let timeZone,
                  let zone = TimeZone(identifier: timeZone),
                  let date = TaskItem.isoFraction.date(from: dueAt)
                    ?? TaskItem.isoWholeSecond.date(from: dueAt) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return nil
            }
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

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
}
