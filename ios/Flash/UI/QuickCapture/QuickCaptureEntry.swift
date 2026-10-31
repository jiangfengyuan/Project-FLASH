// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 快速记录常驻入口（iOS 版全局热键）：
/// - iOS 26+：标签栏上方的系统底部配件（Liquid Glass，随标签栏收起而内联），挂在 TabView 上；
/// - iOS 18–25：右下角悬浮按钮，挂在各 Tab 的导航栈上，经 safeAreaInset 占位——
///   自动避开标签栏与 Home 指示条，列表末行也不会被按钮盖住（不再写死标签栏高度）。
struct QuickCaptureEntryModifier: ViewModifier {
    let zoomNamespace: Namespace.ID
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .tabViewBottomAccessory {
                    Button(action: action) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "sparkle")
                                .foregroundStyle(BrandColors.brandPrimary)
                            Text("现在想记录什么？")
                                .foregroundStyle(BrandColors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .contentShape(Rectangle())
                        // 底部配件高度固定（同标签栏）：字号封顶，超大字号下不溢出截断
                        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    }
                    .buttonStyle(.plain)
                    .flashZoomSource(id: "quickCapture", in: zoomNamespace)
                    .accessibilityLabel("快速记录")
                }
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

/// iOS 18–25 的悬浮按钮（逐 Tab 挂载）。isActive：仅当前 Tab 作为缩放转场源，避免多个同 id 源
struct QuickCaptureFloatingButtonModifier: ViewModifier {
    let zoomNamespace: Namespace.ID
    let isActive: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                    Button(action: action) {
                        Image(systemName: "sparkle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56) // 悬浮按钮尺寸（几何值）
                            .background(BrandColors.brandPrimary, in: Circle())
                            .flashElevatedShadow()
                    }
                    .modifier(ActiveZoomSource(isActive: isActive, namespace: zoomNamespace))
                    .accessibilityLabel("快速记录")
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, Spacing.sm)
                }
        }
    }

    private struct ActiveZoomSource: ViewModifier {
        let isActive: Bool
        let namespace: Namespace.ID

        func body(content: Content) -> some View {
            if isActive {
                content.flashZoomSource(id: "quickCapture", in: namespace)
            } else {
                content
            }
        }
    }
}

extension View {
    func quickCaptureEntry(zoomNamespace: Namespace.ID, action: @escaping () -> Void) -> some View {
        modifier(QuickCaptureEntryModifier(zoomNamespace: zoomNamespace, action: action))
    }

    func quickCaptureFloatingButton(zoomNamespace: Namespace.ID, isActive: Bool,
                                    action: @escaping () -> Void) -> some View {
        modifier(QuickCaptureFloatingButtonModifier(zoomNamespace: zoomNamespace, isActive: isActive, action: action))
    }
}
