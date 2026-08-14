import SwiftUI

struct Sidebar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        List(selection: $state.selectedModule) {
            Section("记录") {
                ForEach([Module.home, .explore, .logflow, .emotion]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }
            Section("回顾") {
                ForEach([Module.calendar, .stats]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }
            Section {
                Label(Module.settings.title, systemImage: Module.settings.systemImage)
                    .tag(Module.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Flash")
    }
}
