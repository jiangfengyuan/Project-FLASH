// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UserNotifications
import FlashCore

/// 本地通知交互：前台也展示横幅；点按通知按 userInfo["url"] 深链跳转（灵感提醒 → flash://ideas）。
/// 无可变状态，可安全跨线程共享（通知回调在非主线程到达）
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        // 任务提醒「完成 / 稍后」：不打开 App，直接写库并重排
        let actionIdentifier = response.actionIdentifier
        if let taskID = userInfo[TaskReminderScheduler.taskIDKey] as? String,
           actionIdentifier != UNNotificationDefaultActionIdentifier,
           actionIdentifier != UNNotificationDismissActionIdentifier {
            await Self.performTaskAction(actionIdentifier, taskID: taskID)
            return
        }
        guard actionIdentifier == UNNotificationDefaultActionIdentifier,
              let link = userInfo["url"] as? String,
              let url = URL(string: link) else { return }
        await MainActor.run {
            _ = IntentBridge.appState?.handle(url: url)
        }
    }

    @MainActor
    private static func performTaskAction(_ actionIdentifier: String, taskID: String) async {
        guard let repository = IntentBridge.repository else { return }
        await TaskReminderActions.perform(actionIdentifier: actionIdentifier, taskID: taskID,
                                          repository: repository)
    }
}
