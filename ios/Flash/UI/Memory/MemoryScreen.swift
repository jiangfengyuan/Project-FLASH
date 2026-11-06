// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// Memory 周报（iOS 外壳）：共享 MemoryView（周导航与报告卡片），标题交给系统导航栏
struct MemoryScreen: View {
    var body: some View {
        MemoryView()
            .navigationTitle("Memory")
            .toolbar { GlobalSearchToolbarItem() }
    }
}
