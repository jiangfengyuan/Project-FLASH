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
            CommandGroup(replacing: .newItem) {
                Button("新建记录") { appState.requestNewLog() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .importExport) {
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
