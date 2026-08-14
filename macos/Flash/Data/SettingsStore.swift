import Foundation

enum ThemeMode: String, CaseIterable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

/// 对应 Android SettingsStore（Mac 版仅保留 themeMode/welcomed，UI 风格固定 HIG）。
final class SettingsStore: ObservableObject {
    @Published private(set) var themeMode: ThemeMode
    @Published private(set) var welcomed: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.themeMode)
        self.themeMode = stored.flatMap(ThemeMode.init(rawValue:)) ?? .system
        self.welcomed = defaults.bool(forKey: Keys.welcomed)
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: Keys.themeMode)
    }

    func setWelcomed() {
        welcomed = true
        defaults.set(true, forKey: Keys.welcomed)
    }

    private enum Keys {
        static let themeMode = "themeMode"
        static let welcomed = "welcomed"
    }
}
