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
    }
}
