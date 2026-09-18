// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 记录页筛选条件（标签 / 重要度 / 日期范围；类型由筛选胶囊承担）。
/// 空值表示不限；isActive 驱动「筛选」按钮高亮与空态「清除筛选」。
struct ExploreCriteria: Equatable {
    var tag: ColorTag? = nil
    var minImportance: Int = 0
    var startDate: Date? = nil
    var endDate: Date? = nil

    var isActive: Bool {
        tag != nil || minImportance > 0 || startDate != nil || endDate != nil
    }

    mutating func clear() { self = ExploreCriteria() }
}

/// 记录页筛选面板（popover 承载，关闭后状态保留在 ExploreView 的 @State 中）。
/// 控件用实色卡片分组（FormSection 语义），可选日期用 Toggle + DatePicker 组合。
struct ExploreFilterPanel: View {
    @Binding var criteria: ExploreCriteria
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("筛选")
                    .font(.headline)
                    .foregroundStyle(BrandColors.textPrimary)
                Spacer()
                Button("清除筛选") { onClear() }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColors.brandPrimary)
                    .disabled(!criteria.isActive)
                    .opacity(criteria.isActive ? 1 : 0.4)
            }

            SolidCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("标签")
                        .font(.callout)
                        .foregroundStyle(BrandColors.textSecondary)
                    Picker("标签", selection: $criteria.tag) {
                        Text("不限").tag(ColorTag?.none)
                        ForEach(ColorTag.allCases, id: \.self) { tag in
                            Text(tag.displayName).tag(ColorTag?.some(tag))
                        }
                    }
                    .labelsHidden()

                    Text("重要度")
                        .font(.callout)
                        .foregroundStyle(BrandColors.textSecondary)
                    Picker("重要度", selection: $criteria.minImportance) {
                        Text("不限").tag(0)
                        ForEach(1...4, id: \.self) { level in
                            Text("\(level) 级及以上").tag(level)
                        }
                    }
                    .labelsHidden()

                    Text("日期范围")
                        .font(.callout)
                        .foregroundStyle(BrandColors.textSecondary)
                    OptionalDateRow(title: "开始日期", date: $criteria.startDate)
                    OptionalDateRow(title: "结束日期", date: $criteria.endDate)
                }
                .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
        .frame(width: 280)
        .background(BrandColors.pageBackground)
    }
}

/// 可选日期行：Toggle 控制启用，启用后展示 DatePicker（.date）。
/// 关闭时把绑定值置 nil（清除该维度条件）。
private struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?

    private var enabled: Binding<Bool> {
        Binding(
            get: { date != nil },
            set: { date = $0 ? (date ?? Date()) : nil }
        )
    }

    private var dateValue: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle(title, isOn: enabled)
                .toggleStyle(.checkbox)
            if date != nil {
                DatePicker(title, selection: dateValue, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    @Previewable @State var criteria = ExploreCriteria(minImportance: 2)
    ExploreFilterPanel(criteria: $criteria) {}
}
