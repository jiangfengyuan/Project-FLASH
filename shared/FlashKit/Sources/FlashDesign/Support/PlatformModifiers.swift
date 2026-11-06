// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

/// 跨平台差异修饰器：共享视图只在这里分平台，调用点保持一行。
public extension View {
    /// 弹层固有宽度：macOS 的 sheet/popover 需要定宽；iOS 由系统 sheet 决定宽度
    @ViewBuilder
    func flashPanelWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(width: width)
        #else
        self
        #endif
    }

    /// 复选框样式：macOS 用 checkbox，触屏用系统开关
    @ViewBuilder
    func flashCheckboxToggleStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.switch)
        #endif
    }
}

public extension EnvironmentValues {
    /// 宿主用系统导航栏承载页标题（iOS NavigationStack）时置 true：
    /// 共享页面隐藏自绘大标题，仅保留页内控件（分段、周导航等）
    @Entry var flashUsesSystemNavigationTitle: Bool = false
}

public extension View {
    /// 编辑弹层外壳：iOS 包进 NavigationStack，标题与「取消 / 保存」进导航栏（键盘弹出时仍可点）；
    /// macOS 原样返回（弹层自带标题与底部按钮行）
    @ViewBuilder
    func flashEditorChrome(title: String, saveTitle: String = "保存", saveDisabled: Bool,
                           onCancel: @escaping () -> Void, onSave: @escaping () -> Void) -> some View {
        #if os(iOS)
        NavigationStack {
            self
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle, action: onSave)
                            .fontWeight(.semibold)
                            .disabled(saveDisabled)
                    }
                }
        }
        #else
        self
        #endif
    }

    /// 触感反馈（PRD v3 §3.5.3：保存成功 Success、删除 Light）：只在触屏平台生效，macOS 不触发触控板反馈
    @ViewBuilder
    func flashHaptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        #if os(iOS)
        sensoryFeedback(feedback, trigger: trigger)
        #else
        self
        #endif
    }
}

public extension View {
    /// 输入框样式：macOS 圆角边框；iOS 表单行内用系统默认（行本身已有分组底）
    @ViewBuilder
    func flashRoundedFieldStyle() -> some View {
        #if os(macOS)
        textFieldStyle(.roundedBorder)
        #else
        self
        #endif
    }
}

public extension View {
    /// 缩放转场的来源（卡片 → 编辑弹层）：iOS 18 matchedTransitionSource；macOS 无对应转场，原样返回
    @ViewBuilder
    func flashZoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        matchedTransitionSource(id: id, in: namespace)
        #else
        self
        #endif
    }

    /// 缩放转场的目标（弹层内容）：从来源卡片放大展开、关闭时缩回原位；Reduce Motion 下系统自动退化为淡入淡出
    @ViewBuilder
    func flashZoomTransition(sourceID: some Hashable, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
        navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        #else
        self
        #endif
    }
}
