// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WidgetKit

/// iOS 小组件扩展：主屏「Flash 此刻」（小 / 中）、锁屏三种尺寸，以及控制中心「快速记录」控件
@main
struct FlashWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlashTodayWidget()
        FlashLockScreenWidget()
        QuickCaptureControl()
    }
}
