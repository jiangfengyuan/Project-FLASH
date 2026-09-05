// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 备份契约文本上限（app/docs/contracts/README.md §3），UTF-16 单元口径：
/// 正文/备注 ≤ 100,000，任务标题 ≤ 200。与 BackupService.maxTextLength、
/// Android FlashRepository 的 take(100_000) 一致；emoji 通常占 2 个单元，
/// 不等于 Character.count，因此各写入口统一走这里的 utf16.count 校验。
enum TextLimits {
    static let maxContentUTF16 = 100_000
    static let maxTaskTitleUTF16 = 200

    static func fits(_ text: String, limit: Int = maxContentUTF16) -> Bool {
        text.utf16.count <= limit
    }
}
