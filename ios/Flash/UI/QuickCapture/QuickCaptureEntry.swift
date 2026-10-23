// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashDesign

/// 快速记录常驻入口（iOS 版全局热键）：
/// - iOS 26+：标签栏上方的系统底部配件（Liquid Glass，随标签栏收起而内联）；
/// - iOS 18–25：右下角悬浮按钮（材质背景），位于标签栏之上。
struct QuickCaptureEntryModifier: ViewModifier {
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
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("快速记录")
                }
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
                .overlay(alignment: .bottomTrailing) {
                    Button(action: action) {
                        Image(systemName: "sparkle")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56) // 悬浮按钮尺寸（几何值）
                            .background(BrandColors.brandPrimary, in: Circle())
                            .flashElevatedShadow()
                    }
                    .accessibilityLabel("快速记录")
                    .padding(.trailing, Spacing.md)
                    .padding(.bottom, 64) // 让出标签栏高度（几何值）
                }
        }
    }
}

extension View {
    func quickCaptureEntry(action: @escaping () -> Void) -> some View {
        modifier(QuickCaptureEntryModifier(action: action))
    }
}
