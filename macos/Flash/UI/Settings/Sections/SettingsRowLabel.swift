// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 分组清单行：彩色语义图标 + 标题。图标色仅作分组语义点缀（蓝=外观、绿=安全、红=危险），
/// 信息由标题文字承载，色彩不是唯一通道。
/// 图标列宽固定基准 20、随系统字体档位缩放，保证各行标题左对齐。
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    /// 图标列宽（图标框场景：固定基准 + @ScaledMetric）
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = 20

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: iconColumnWidth, alignment: .center)
        }
    }
}
