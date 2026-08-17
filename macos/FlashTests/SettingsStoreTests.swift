// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Testing
import Foundation
@testable import Flash

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
}
