// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 跨平台差异修饰器：共享视图只在这里分平台，调用点保持一行。
public extension View {
    /// 弹层固有宽度：macOS 的 sheet/popover 需要定宽；iOS 由系统 sheet 决定宽度
    @ViewBuilder
    func flashPanelWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width)
        #else
        self
        #endif
    }

    /// 复选框样式：macOS 用 checkbox，触屏用系统开关
    @ViewBuilder
    func flashCheckboxToggleStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.switch)
        #endif
    }
}

public extension EnvironmentValues {
    /// 宿主用系统导航栏承载页标题（iOS NavigationStack）时置 true：
    /// 共享页面隐藏自绘大标题，仅保留页内控件（分段、周导航等）
    @Entry var flashUsesSystemNavigationTitle: Bool = false
}
