// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum DateFormatting {
    // Swift 6 并发检查：formatter 实例仅在各方法内短时使用，标记 nonisolated(unsafe)
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated(unsafe) private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    nonisolated(unsafe) private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    nonisolated(unsafe) private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 无毫秒位的 ISO-8601 解析兜底（isoFormatter 要求带毫秒）
    nonisolated(unsafe) private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// ISO-8601（与 JS Date#toISOString / Android ISO_INSTANT 同格式）
    static func isoNow() -> String { isoFormatter.string(from: Date()) }

    /// yyyy-MM-dd 本地日期
    static func today() -> String { dayFormatter.string(from: Date()) }

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    static func parseDay(_ string: String) -> Date? { dayFormatter.date(from: string) }

    /// yyyy-MM 本地月份
    static func monthString(_ date: Date) -> String { monthFormatter.string(from: date) }

    /// 中文月份标题，如「2026年8月」
    static func monthTitle(_ date: Date) -> String { monthTitleFormatter.string(from: date) }

    /// ISO-8601 → 本地时区 HH:mm；解析失败返回 "--:--"
    static func localTime(fromISO iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) ?? isoFormatterNoFraction.date(from: iso)
        else { return "--:--" }
        return timeFormatter.string(from: date)
    }
}
