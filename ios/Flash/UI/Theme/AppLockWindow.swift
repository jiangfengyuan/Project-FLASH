// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit
import FlashCore
import FlashDesign

/// 应用锁的遮挡窗口。和 PrivacyShield 一样用独立高层级窗口：搜索、快速记录、记录编辑等 sheet
/// 都在根视图之上，overlay 遮不住。层级比 PrivacyShield 低一档，多任务快照仍由纸面遮罩负责。
/// 锁定时的快速记录从这个窗口自己弹出（只写不读），所以小组件 / 控制中心 / 快捷指令照常可用。
@MainActor
final class AppLockWindow {
    static let shared = AppLockWindow()

    private var windows: [ObjectIdentifier: UIWindow] = [:]

    func update(isLocked: Bool, content: () -> AppLockRoot) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard isLocked else {
            windows.values.forEach { $0.isHidden = true }
            windows.removeAll()
            // 交还键盘与 VoiceOver 焦点给主窗口
            for scene in scenes {
                scene.windows.first { $0.windowLevel == .normal }?.makeKey()
            }
            return
        }
        for scene in scenes where windows[ObjectIdentifier(scene)] == nil {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert
            let host = UIHostingController(rootView: content())
            window.rootViewController = host
            window.makeKeyAndVisible()
            windows[ObjectIdentifier(scene)] = window
        }
    }
}

/// 锁定窗口的根：锁定页 + 锁定时的快速记录面板。
struct AppLockRoot: View {
    let lock: AppLockController
    let appState: AppState
    @ObservedObject var settings: SettingsStore
    let repository: FlashRepository?

    var body: some View {
        @Bindable var appState = appState
        AppLockScreen(onQuickCapture: { appState.presentQuickCapture() })
            .sheet(item: $appState.quickCapture) { request in
                QuickCaptureSheet(initialCategory: request.category)
                    .id(request.id)
            }
            .environment(lock)
            .environment(\.flashRepository, repository)
            .environmentObject(settings)
            .preferredColorScheme(settings.themeMode.colorScheme)
            .tint(BrandColors.brandPrimary)
    }
}
