// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import FlashCore

@Suite("SettingsStore")
struct SettingsStoreTests {
    /// 独立随机 suite，避免污染标准 defaults；各测试 defer 清理残留
    private func makeSuite() -> (name: String, suite: UserDefaults) {
        let name = "test-\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func defaultsAreSystemAndNotWelcomed() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: suite)
        #expect(store.themeMode == .system)
        #expect(!store.welcomed)
    }

    @Test func setThemeModePersists() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        SettingsStore(defaults: suite).setThemeMode(.dark)
        #expect(SettingsStore(defaults: suite).themeMode == .dark)
    }

    @Test func invalidStoredValueFallsBackToSystem() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        suite.set("weird", forKey: "themeMode")
        #expect(SettingsStore(defaults: suite).themeMode == .system)
    }

    @Test func setWelcomedPersists() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: suite)
        store.setWelcomed()
        #expect(store.welcomed)
    }

    @Test func themeModeDisplayNames() {
        #expect(ThemeMode.system.displayName == "跟随系统")
        #expect(ThemeMode.light.displayName == "浅色")
        #expect(ThemeMode.dark.displayName == "深色")
    }

    // MARK: - Quick Capture 快捷键

    @Test func quickCaptureHotkeyDefaultsToCmdShiftSpace() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        #expect(SettingsStore(defaults: suite).quickCaptureHotkey == .defaultQuickCapture)
    }

    @Test func setQuickCaptureHotkeyPersists() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let chord = KeyChord(keyCode: 38, modifiers: CarbonKeyModifiers.option | CarbonKeyModifiers.command)
        SettingsStore(defaults: suite).setQuickCaptureHotkey(chord)
        #expect(SettingsStore(defaults: suite).quickCaptureHotkey == chord)
    }

    @Test func corruptQuickCaptureHotkeyFallsBackToDefault() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        suite.set(Data("not json".utf8), forKey: "quickCaptureHotkey")
        #expect(SettingsStore(defaults: suite).quickCaptureHotkey == .defaultQuickCapture)
    }

    // MARK: - 辅助功能 / 新手引导

    @Test func accessibilityPreferencesDefault() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: suite)
        #expect(!store.reduceMotion)
        #expect(store.textSize == .system)
        #expect(store.hapticsEnabled)
    }

    @Test func accessibilityPreferencesPersist() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: suite)
        store.setReduceMotion(true)
        store.setTextSize(.extraLarge)
        store.setHapticsEnabled(false)
        let reloaded = SettingsStore(defaults: suite)
        #expect(reloaded.reduceMotion)
        #expect(reloaded.textSize == .extraLarge)
        #expect(!reloaded.hapticsEnabled)
    }

    @Test func invalidTextSizeFallsBackToSystem() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        suite.set("huge", forKey: "textSize")
        #expect(SettingsStore(defaults: suite).textSize == .system)
    }

    @Test func resetWelcomedOnlyClearsTheOnboardingFlag() {
        let (name, suite) = makeSuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: suite)
        store.setThemeMode(.dark)
        store.setWelcomed()
        store.resetWelcomed()
        let reloaded = SettingsStore(defaults: suite)
        #expect(!reloaded.welcomed)
        #expect(reloaded.themeMode == .dark)
    }
}
