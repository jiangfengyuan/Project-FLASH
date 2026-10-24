// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import FlashCore

/// `Category` 与 ObjectiveC 运行时的 `Category`（OpaquePointer）同名，跨模块引用时类型查找歧义；
/// 模块内别名优先于导入声明，消除歧义。使用 FlashCore 的每个模块各放一份。
typealias Category = FlashCore.Category
