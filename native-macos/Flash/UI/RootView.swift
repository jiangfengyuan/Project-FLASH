import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 225, ideal: 240, max: 350)
        } detail: {
            detailView(for: appState.selectedModule)
                .navigationTitle(appState.selectedModule.title)
                .frame(minWidth: 560, minHeight: 480)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    @ViewBuilder
    private func detailView(for module: Module) -> some View {
        switch module {
        case .home: HomeView()
        case .explore: ExploreView()
        case .logflow: LogFlowView()
        case .emotion: EmotionView()
        case .calendar: CalendarView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }
}
