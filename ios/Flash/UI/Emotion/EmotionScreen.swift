// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 情绪页（iOS 外壳）：共享 EmotionView（情绪选择 / 本周 / 历史），独立成 Tab，标题交给系统导航栏
struct EmotionScreen: View {
    var body: some View {
        EmotionView()
            .navigationTitle("情绪")
            .toolbar { GlobalSearchToolbarItem() }
    }
}
