// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import OSLog

/// 性能观测：OSSignposter 封装（subsystem 与 Bundle ID 一致）。
/// 在 Instruments 的 Points of Interest / os_signpost 模板中按名称过滤。
enum Perf {
    private static let signposter = OSSignposter(subsystem: "com.flash.app.macos",
                                                 category: .pointsOfInterest)

    /// 同步区间测量：`Perf.measure("StatsAggregate") { ... }`
    @discardableResult
    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try work()
    }

    /// 点事件（启动里程碑等）
    static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
