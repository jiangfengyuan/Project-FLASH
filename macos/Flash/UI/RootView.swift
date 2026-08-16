import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 225, ideal: 240, max: 350)
        } detail: {
            detailView(for: appState.selectedModule)
                .id(appState.selectedModule)
                .transition(pageTransition)
                .animation(.easeOut(duration: reduceMotion ? 0.15 : 0.2), value: appState.selectedModule)
                .navigationTitle(appState.selectedModule.title)
                .frame(minWidth: 560, minHeight: 480)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    /// 页面过渡：淡入淡出 + 极轻上移；减弱动态时仅淡入淡出
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(y: 6))
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
