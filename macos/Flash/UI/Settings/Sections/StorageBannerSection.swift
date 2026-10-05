// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 本地存储说明横幅（Form 顶部无标题分组）
struct StorageBannerSection: View {
    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("数据默认保存在此设备")
                        .font(.headline)
                    Text("可导出备份或在可信局域网内传输")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "internaldrive")
                    .foregroundStyle(BrandColors.brandPrimary)
            }
        }
    }
}
