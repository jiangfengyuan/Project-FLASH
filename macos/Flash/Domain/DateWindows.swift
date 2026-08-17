// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 日期窗口工具，输出 yyyy-MM-dd 字符串数组（字典序即时间序）。
enum DateWindows {
    /// 最近 n 天（含今天），升序、今天结尾；n <= 0 时返回空数组。
    static func lastNDays(_ n: Int, today: Date = Date()) -> [String] {
        guard n > 0 else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        return (0..<n).map { i in
            DateFormatting.dayString(calendar.date(byAdding: .day, value: i - (n - 1), to: today)!)
        }
    }

    /// 本周一到周日共 7 天，升序。
    static func currentWeek(today: Date = Date()) -> [String] {
        let calendar = Calendar(identifier: .gregorian)
        // weekday: 1=周日 2=周一 ... 7=周六 → 周一偏移 = (weekday + 5) % 7
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -offset, to: today)!
        return (0..<7).map { i in
            DateFormatting.dayString(calendar.date(byAdding: .day, value: i, to: monday)!)
        }
    }
}
