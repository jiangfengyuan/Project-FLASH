import SwiftUI
import SwiftData

@main
struct FlashApp: App {
    private let container: ModelContainer
    @State private var appState = AppState()
    @StateObject private var settings = SettingsStore()
    @Environment(\.openWindow) private var openWindow

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
        .commands {
            CommandGroup(after: .newItem) {
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
