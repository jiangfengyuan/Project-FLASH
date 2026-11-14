// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import AppKit
import FlashCore

/// 应用锁的生命周期转发（Mac）：失去激活计时，重新激活时按宽限期判定；
/// 睡眠与锁屏立即上锁。挂在进程级单例上：主窗口关掉（菜单栏驻留）时也不漏事件。
@MainActor
final class AppLockObserver {
    static let shared = AppLockObserver()

    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    func start(_ lock: AppLockController) {
        guard tokens.isEmpty else { return }
        let app = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observe(app, NSApplication.didResignActiveNotification) { lock.didEnterBackground() }
        observe(app, NSApplication.didBecomeActiveNotification) {
            lock.willEnterForeground()
            Task { await lock.autoPromptIfNeeded(reason: "解锁 Flash 以查看你的记录") }
        }
        observe(workspace, NSWorkspace.willSleepNotification) { lock.lockNow() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { lock.lockNow() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { lock.lockNow() }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { lock.lockNow() }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ action: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        tokens.append((center, token))
    }
}
