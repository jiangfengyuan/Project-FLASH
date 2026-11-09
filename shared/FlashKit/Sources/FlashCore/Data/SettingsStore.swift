// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum ThemeMode: String, CaseIterable, Sendable {
    case system, light, dark

    public var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

/// 应用内文字大小偏好（辅助功能）：在系统字体档位之上再设一个下限。
/// 「跟随系统」不干预；「较大」「特大」只抬高下限，系统档位更大时仍以系统为准。
/// macOS 无动态字体，仅 iOS 生效。
public enum TextSizePreference: String, CaseIterable, Sendable {
    case system, large, extraLarge

    public var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .large: "较大"
        case .extraLarge: "特大"
        }
    }
}

/// 对应 Android SettingsStore（Mac 版仅保留 themeMode/welcomed，UI 风格固定 HIG）。
public final class SettingsStore: ObservableObject {
    @Published public private(set) var themeMode: ThemeMode
    @Published public private(set) var welcomed: Bool
    /// Quick Capture 全局快捷键（PRD §13.2），缺省 ⌘⇧Space；
    /// setter 发布 @Published，QuickCaptureController 订阅后通知 GlobalHotKeyService 重注册
    @Published public private(set) var quickCaptureHotkey: KeyChord
    /// 灵感提醒推送开关与频率（iOS 设置页；默认开启、每天）
    @Published public private(set) var ideaReminderEnabled: Bool
    @Published public private(set) var ideaReminderFrequency: IdeaReminder.Frequency
    /// 辅助功能：应用内「减少动态效果」。与系统「减弱动态效果」取或——任一开启即生效
    @Published public private(set) var reduceMotion: Bool
    /// 辅助功能：应用内文字大小下限（iOS）
    @Published public private(set) var textSize: TextSizePreference
    /// 辅助功能：触感反馈（iOS），默认开启
    @Published public private(set) var hapticsEnabled: Bool

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 灵感提醒推送：默认开启、每天（PRD v3 §6.3）
        self.ideaReminderEnabled = defaults.object(forKey: Keys.ideaReminderEnabled) as? Bool ?? true
        self.ideaReminderFrequency = defaults.string(forKey: Keys.ideaReminderFrequency)
            .flatMap(IdeaReminder.Frequency.init(rawValue:)) ?? .daily
        let stored = defaults.string(forKey: Keys.themeMode)
        self.themeMode = stored.flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.welcomed = defaults.bool(forKey: Keys.welcomed)
        self.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        self.textSize = defaults.string(forKey: Keys.textSize)
            .flatMap(TextSizePreference.init(rawValue:)) ?? .system
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        // Codable JSON 存储；缺失或损坏均回退默认 ⌘⇧Space
        if let data = defaults.data(forKey: Keys.quickCaptureHotkey),
           let chord = try? JSONDecoder().decode(KeyChord.self, from: data) {
            self.quickCaptureHotkey = chord
        } else {
            self.quickCaptureHotkey = .defaultQuickCapture
        }
    }

    public func setIdeaReminderEnabled(_ enabled: Bool) {
        ideaReminderEnabled = enabled
        defaults.set(enabled, forKey: Keys.ideaReminderEnabled)
    }

    public func setIdeaReminderFrequency(_ frequency: IdeaReminder.Frequency) {
        ideaReminderFrequency = frequency
        defaults.set(frequency.rawValue, forKey: Keys.ideaReminderFrequency)
    }

    public func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: Keys.themeMode)
    }

    public func setWelcomed() {
        welcomed = true
        defaults.set(true, forKey: Keys.welcomed)
    }

    /// 设置页「重新查看新手引导」：只清除引导标记，不触碰任何记录数据或其它偏好
    public func resetWelcomed() {
        welcomed = false
        defaults.set(false, forKey: Keys.welcomed)
    }

    public func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        defaults.set(enabled, forKey: Keys.reduceMotion)
    }

    public func setTextSize(_ size: TextSizePreference) {
        textSize = size
        defaults.set(size.rawValue, forKey: Keys.textSize)
    }

    public func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        defaults.set(enabled, forKey: Keys.hapticsEnabled)
    }

    public func setQuickCaptureHotkey(_ chord: KeyChord) {
        quickCaptureHotkey = chord
        if let data = try? JSONEncoder().encode(chord) {
            defaults.set(data, forKey: Keys.quickCaptureHotkey)
        }
    }

    private enum Keys {
        static let ideaReminderEnabled = "ideaReminderEnabled"
        static let ideaReminderFrequency = "ideaReminderFrequency"
        static let themeMode = "themeMode"
        static let welcomed = "welcomed"
        static let quickCaptureHotkey = "quickCaptureHotkey"
        static let reduceMotion = "reduceMotion"
        static let textSize = "textSize"
        static let hapticsEnabled = "hapticsEnabled"
    }
}
