// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// 界面文案的本地化入口（键即简体中文原文）。
///
/// 从主 Bundle 的 String Catalog 查：iOS App 与各扩展各带一份目录；macOS 没有目录，
/// 查不到就返回中文原文，因此 macOS 界面保持中文。存储值（日期、ID、备份字段）不得走这里。
public func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .main)
}
