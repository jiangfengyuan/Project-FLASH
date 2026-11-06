// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import OSLog

/// 性能观测：OSSignposter 封装（subsystem 取宿主 App 的 Bundle ID：macOS com.flash.app.macos / iOS com.flash.app.ios）。
/// 在 Instruments 的 Points of Interest / os_signpost 模板中按名称过滤。
public enum Perf: Sendable {
    private static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.flash.app",
                                                 category: .pointsOfInterest)

    /// 同步区间测量：`Perf.measure("StatsAggregate") { ... }`
    @discardableResult
    public static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try work()
    }

    /// 点事件（启动里程碑等）
    public static func event(_ name: StaticString) {
        signposter.emitEvent(name)
    }
}
