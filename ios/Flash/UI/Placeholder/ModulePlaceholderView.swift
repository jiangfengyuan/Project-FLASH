// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 尚未移植到 iOS 的一级模块占位页（共享 EmptyStateView，随里程碑替换为真实页面）
struct ModulePlaceholderView: View {
    let tab: AppTab

    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: tab.systemImage,
                title: "\(tab.title)即将上线",
                message: "iOS 版正在逐个模块移植，此页暂未开放。数据已与 macOS 共用同一套存储与备份格式。"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColors.pageBackground)
            .navigationTitle(tab.title)
        }
    }
}
