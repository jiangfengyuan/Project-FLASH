// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os

/// 诊断日志（F-17）：替代 `print("… \(error)")`。
///
/// SwiftData / JSON 错误的描述可能带记录正文与文件路径，`print` 在 Release 里原样保留。
/// 这里事件名与错误类型公开（便于定位），错误详情标为 `.private`：
/// 附着调试器时可见，设备日志与 sysdiagnose 中显示为 `<private>`。
public enum FlashLog {
    private static let logger = Logger(subsystem: "com.flash.app", category: "diagnostics")

    /// - Parameter event: 稳定的 snake_case 事件名（不含用户内容），如 `backup_export_failed`
    public static func failure(_ event: StaticString, _ error: any Error) {
        let name = "\(event)"
        let type = String(reflecting: Swift.type(of: error))
        let detail = String(describing: error)
        logger.error("\(name, privacy: .public) [\(type, privacy: .public)] \(detail, privacy: .private)")
    }

    /// 无错误对象的事件（如降级提示），只记录事件名
    public static func notice(_ event: StaticString) {
        let name = "\(event)"
        logger.notice("\(name, privacy: .public)")
    }
}
