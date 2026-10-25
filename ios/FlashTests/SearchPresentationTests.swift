import SwiftUI
import SwiftData
import Testing
import UIKit
import FlashCore
@testable import Flash

/// Mount the real root and its sheet: state-only routing tests cannot detect a
/// missing observable environment dependency in the presented hierarchy.
@MainActor
@Suite("iOS 搜索弹层装配", .serialized)
struct SearchPresentationTests {
    @Test func realSearchSheetMountsAndSharesTheNavigationRouter() async throws {
        let suite = "search-presentation-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings.setWelcomed()
        settings.setIdeaReminderEnabled(false)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = FlashDatabase.makeContainer(inMemory: true)
        let repository = FlashRepository(container: container)
        let state = AppState()
        let reminders = IdeaReminderCenter(store: IdeaViewStateStore(directory: directory))
        let root = RootView()
            .environment(state)
            .environment(reminders)
            .environment(\.flashRepository, repository)
            .environmentObject(settings)
            .modelContainer(container)
        let controller = UIHostingController(rootView: root)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            controller.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        state.isSearchPresented = true
        for _ in 0..<120 {
            if let presented = controller.presentedViewController, presented.view.window != nil {
                presented.view.layoutIfNeeded()
                // Let SwiftUI evaluate dynamic environment properties, not just
                // allocate a UIKit presentation controller.
                try await Task.sleep(for: .milliseconds(150))
                #expect(presented.view.window != nil)
                #expect(state.isSearchPresented)
                state.focusRouter.request(.task("2026-10-25"))
                #expect(!state.isSearchPresented)
                #expect(state.selectedTab == .stats)
                #expect(state.statsPath == [.calendar])
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        Issue.record("The real root never mounted its search sheet")
    }
}
