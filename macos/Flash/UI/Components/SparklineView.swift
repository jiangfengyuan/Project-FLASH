// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 统计卡片底部的迷你柱状图（参考稿约 7 根圆角细柱）。
/// 内部归一化到最大值；空数据渲染低矮占位柱，不崩溃。
/// 首次出现与数据切换时柱条自底 stagger 生长（Motion.emphasize；
/// Reduce Motion 下直接完整呈现）。
struct SparklineView: View {
    let values: [Double]
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 柱条展开开关（配合逐项 delay 做 stagger 生长）
    @State private var shown = false

    init(values: [Double], color: Color) {
        self.values = values
        self.color = color
    }

    /// 归一化后的柱高比例（0...1）。空数据/全零时给低矮占位高度。
    private var normalized: [Double] {
        guard !values.isEmpty else { return [0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12] }
        let maxValue = values.max() ?? 0
        guard maxValue > 0 else { return values.map { _ in 0.12 } }
        return values.map { max($0 / maxValue, 0.08) } // 保底可见的最小高度
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { index, ratio in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 4, height: max(proxy.size.height * ratio, 2))
                        .scaleEffect(x: 1, y: shown ? 1 : 0.05, anchor: .bottom)
                        .opacity(shown ? 1 : 0)
                        .animation(
                            Motion.emphasize(reduceMotion)?.delay(Motion.staggerDelay(index)),
                            value: shown)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .onAppear { replay() }
        .onChange(of: values) { _, _ in replay() }
    }

    /// 重播生长动画。重置不进动画事务（异步触发展开），避免首尾状态被合并导致动画丢失。
    private func replay() {
        guard !reduceMotion else {
            shown = true
            return
        }
        shown = false
        DispatchQueue.main.async { shown = true }
    }
}

#Preview {
    SparklineView(values: [2, 5, 3, 8, 4, 6, 7], color: BrandColors.logPurple)
        .frame(width: 80, height: 28)
        .padding()
}
