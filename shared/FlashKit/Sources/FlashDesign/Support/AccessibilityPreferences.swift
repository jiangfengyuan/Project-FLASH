// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import FlashCore

// 应用内辅助功能偏好（设置 › 辅助功能 / 新手引导最后一步）：
// - 减少动态效果：与系统「减弱动态效果」取或，任一开启即关闭位移 / 缩放 / 弹簧动画；
// - 文字大小（iOS）：在系统字体档位上抬高下限；
// - 触感反馈（iOS）：关闭后 flashHaptic 不再触发。
// 偏好由 `flashAccessibilityPreferences(_:)` 在每个场景根部注入（主窗口、菜单栏面板、
// Quick Capture 面板）；sheet / fullScreenCover 继承呈现方的环境。

public extension EnvironmentValues {
    /// 应用内「减少动态效果」开关（不含系统设置；读取请用 `@FlashReduceMotion`）
    @Entry var flashPrefersReducedMotion: Bool = false
    /// 应用内触感反馈开关
    @Entry var flashHapticsEnabled: Bool = true
}

/// 动画裁决：系统「减弱动态效果」或应用内「减少动态效果」任一开启即为 true。
/// 用法同 `@Environment(\.accessibilityReduceMotion)`：`@FlashReduceMotion private var reduceMotion`。
/// 未注入应用偏好的视图（预览、小组件）仍完整遵守系统设置。
@propertyWrapper
public struct FlashReduceMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.flashPrefersReducedMotion) private var preferred

    public init() {}

    public var wrappedValue: Bool { system || preferred }
}

public extension View {
    /// 在场景根部注入应用内辅助功能偏好（随设置实时更新）
    func flashAccessibilityPreferences(_ settings: SettingsStore) -> some View {
        modifier(AccessibilityPreferencesModifier(settings: settings))
    }
}

private struct AccessibilityPreferencesModifier: ViewModifier {
    @ObservedObject var settings: SettingsStore

    func body(content: Content) -> some View {
        content
            .environment(\.flashPrefersReducedMotion, settings.reduceMotion)
            .environment(\.flashHapticsEnabled, settings.hapticsEnabled)
            #if os(iOS)
            // 只抬高下限、上限保留到最大辅助功能档位：系统档位更大时仍以系统为准
            .dynamicTypeSize(settings.textSize.minimumDynamicTypeSize...DynamicTypeSize.accessibility5)
            #endif
    }
}

#if os(iOS)
extension TextSizePreference {
    /// 各档位对应的动态字体下限
    var minimumDynamicTypeSize: DynamicTypeSize {
        switch self {
        case .system: .xSmall
        case .large: .xLarge
        case .extraLarge: .xxxLarge
        }
    }
}
#endif
