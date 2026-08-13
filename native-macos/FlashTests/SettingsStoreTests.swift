import Testing
import Foundation
@testable import Flash

@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeStore() -> SettingsStore {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return SettingsStore(defaults: suite)
    }

    @Test func defaultsAreSystemAndNotWelcomed() {
        let store = makeStore()
        #expect(store.themeMode == .system)
        #expect(!store.welcomed)
    }

    @Test func setThemeModePersists() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        SettingsStore(defaults: suite).setThemeMode(.dark)
        #expect(SettingsStore(defaults: suite).themeMode == .dark)
    }

    @Test func invalidStoredValueFallsBackToSystem() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("weird", forKey: "themeMode")
        #expect(SettingsStore(defaults: suite).themeMode == .system)
    }

    @Test func setWelcomedPersists() {
        let store = makeStore()
        store.setWelcomed()
        #expect(store.welcomed)
    }

    @Test func themeModeDisplayNames() {
        #expect(ThemeMode.system.displayName == "跟随系统")
        #expect(ThemeMode.light.displayName == "浅色")
        #expect(ThemeMode.dark.displayName == "深色")
    }
}
