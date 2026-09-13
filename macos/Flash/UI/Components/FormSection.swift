// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 表单分组容器：组标题 + 实色卡片内容。
/// 用于设置类表单页的分区（对应 Android 组件族的 FormSection）；
/// 标题用次文字令牌，内容承载在 `SolidCard` 中（圆角 24）。
struct FormSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.callout)
                .foregroundStyle(BrandColors.textSecondary)
                .padding(.horizontal, Spacing.sm)
            SolidCard {
                content
            }
        }
    }
}

#Preview {
    FormSection("通用") {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("外观")
            Text("主题跟随系统")
                .font(.subheadline)
                .foregroundStyle(BrandColors.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(Spacing.lg)
    .background(BrandColors.pageBackground)
}
