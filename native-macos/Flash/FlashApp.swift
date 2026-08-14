import SwiftUI
import SwiftData

@main
struct FlashApp: App {
    private let container: ModelContainer
    @State private var appState = AppState()
    @StateObject private var settings = SettingsStore()

    init() {
        self.container = FlashDatabase.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.welcomed {
                    RootView()
                } else {
                    WelcomeView {
                        settings.setWelcomed()
                    }
                }
            }
            .environment(appState)
            .environment(\.flashRepository, FlashRepository(container: container))
            .environmentObject(settings)
            .preferredColorScheme(colorScheme(for: settings.themeMode))
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 760)
        .commands {
            // 单 WindowGroup、无 Settings scene 时系统不会生成「设置 ⌘,」，手动补
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { appState.selectedModule = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
            // .importExport 锚点仅在文档型应用存在，非文档型 WindowGroup 下挂其上的命令组会被系统静默丢弃；
            // 「导出备份…」改挂 .newItem 组内（快捷键 ⇧⌘E 不变）
            CommandGroup(replacing: .newItem) {
                Button("新建记录") { appState.requestNewLog() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("导出备份…") { appState.requestExport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }

    private func colorScheme(for mode: ThemeMode) -> ColorScheme? {
        switch mode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
