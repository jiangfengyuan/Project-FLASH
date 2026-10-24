// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

public extension ThemeMode {
    /// 主题模式 → SwiftUI ColorScheme（nil = 跟随系统）。
    /// macOS 主窗口/菜单栏伴侣/Quick Capture 面板与 iOS 根视图共用同一映射。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
