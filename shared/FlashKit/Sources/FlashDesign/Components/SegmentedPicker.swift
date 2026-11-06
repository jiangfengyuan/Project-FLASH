// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 分段控件：原生 Picker(.segmented) 的统一封装（对应 Android 组件族的 SegmentedControl），
/// 保持桌面端平台惯例，不自绘轨道。选中态动画由系统处理并尊重减少动态。
public struct SegmentedPicker<SelectionValue: Hashable>: View {
    public struct Option: Identifiable {
        public let value: SelectionValue
        public let title: String
        public var id: SelectionValue { value }

        public init(value: SelectionValue, title: String) {
            self.value = value
            self.title = title
        }
    }

    @Binding public var selection: SelectionValue
    public let options: [Option]

    public init(selection: Binding<SelectionValue>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

#Preview {
    @Previewable @State var selection = 0
    SegmentedPicker(
        selection: $selection,
        options: [
            .init(value: 0, title: "日"),
            .init(value: 1, title: "周"),
            .init(value: 2, title: "月"),
        ]
    )
    .padding(Spacing.lg)
}
