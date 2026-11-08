// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

/// 设置 › 辅助功能：减少动态效果、文字大小（iOS）、触感反馈（iOS）与「重新查看新手引导」。
/// 偏好即时生效（`flashAccessibilityPreferences` 在场景根部观察 SettingsStore）。
public struct AccessibilitySection: View {
    @EnvironmentObject private var settings: SettingsStore
    /// 只读系统设置：系统已开启时在说明里告知用户，应用内开关不再起额外作用
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// 分组入场标记（stagger 淡入上移），由宿主设置页驱动；iOS 传 true
    public let appeared: Bool
    public let onReplayOnboarding: () -> Void

    public init(appeared: Bool = true, onReplayOnboarding: @escaping () -> Void) {
        self.appeared = appeared
        self.onReplayOnboarding = onReplayOnboarding
    }

    public var body: some View {
        Section {
            Toggle(isOn: reduceMotionBinding) {
                SettingsRowLabel(title: "减少动态效果", systemImage: "slowmo", color: .blue)
            }
            .accessibilityHint("关闭页面切换、卡片入场与弹性动画，只保留淡入淡出")

            #if os(iOS)
            Picker(selection: textSizeBinding) {
                ForEach(TextSizePreference.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            } label: {
                SettingsRowLabel(title: "文字大小", systemImage: "textformat.size", color: .blue)
            }
            .accessibilityHint("在系统字体大小之上设定最小字号；系统设置更大时以系统为准")

            Toggle(isOn: hapticsBinding) {
                SettingsRowLabel(title: "触感反馈", systemImage: "iphone.radiowaves.left.and.right",
                                 color: .blue)
            }
            #endif

            Button(action: onReplayOnboarding) {
                SettingsRowLabel(title: "重新查看新手引导", systemImage: "play.rectangle",
                                 color: BrandColors.brandPrimary)
            }
            .accessibilityHint("重新打开首次使用时的介绍与偏好设置，不影响已有记录")
        } header: {
            Text("辅助功能")
        } footer: {
            Text(footerText)
        }
        .opacity(appeared ? 1 : 0)
    }

    private var footerText: String {
        if systemReduceMotion {
            return "系统已开启「减弱动态效果」，应用内动画已自动减少。"
        }
        #if os(iOS)
        return "也会遵循系统的「减弱动态效果」与「更大字体」设置。"
        #else
        return "也会遵循系统的「减弱动态效果」设置。"
        #endif
    }

    private var reduceMotionBinding: Binding<Bool> {
        Binding(get: { settings.reduceMotion }, set: { settings.setReduceMotion($0) })
    }

    #if os(iOS)
    private var textSizeBinding: Binding<TextSizePreference> {
        Binding(get: { settings.textSize }, set: { settings.setTextSize($0) })
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { settings.hapticsEnabled }, set: { settings.setHapticsEnabled($0) })
    }
    #endif
}
