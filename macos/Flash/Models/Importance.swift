// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 与 Web 版 getImportanceFromContent 对齐：从内容中的 !! 标记推断重要度
func importanceFromContent(_ content: String) -> Int {
    if content.contains("!!!!") { return 4 }
    if content.contains("!!!") { return 3 }
    if content.contains("!!") { return 2 }
    return 0
}
