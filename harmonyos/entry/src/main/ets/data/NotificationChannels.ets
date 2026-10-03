// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';

const NOTIFICATION_SETTINGS_SYSCAP = 'SystemCapability.Notification.NotificationSettings';

/** 通知渠道：任务提醒使用服务类渠道（响铃 + 横幅），其余平台能力按系统能力位降级。 */
export class NotificationChannels {
  private static reminderSlotReady: Promise<void> | null = null;

  static reminderSlotType(): notificationManager.SlotType | undefined {
    return notificationManager.SlotType?.SERVICE_INFORMATION;
  }

  static supportsNotificationSettings(): boolean {
    try {
      return typeof canIUse === 'function' && canIUse(NOTIFICATION_SETTINGS_SYSCAP);
    } catch (_) {
      return false;
    }
  }

  /** 幂等创建任务提醒渠道；创建失败不阻断发布，下次重建时重试。 */
  static ensureReminderSlot(context: common.UIAbilityContext): Promise<void> {
    if (!NotificationChannels.reminderSlotReady) {
      NotificationChannels.reminderSlotReady = NotificationChannels.createReminderSlot();
    }
    return NotificationChannels.reminderSlotReady;
  }

  /** 半模态拉起本应用通知设置页；低版本或设备不支持时返回 false。 */
  static async openAppNotificationSettings(context: common.UIAbilityContext): Promise<boolean> {
    if (!NotificationChannels.supportsNotificationSettings()) return false;
    try {
      await notificationManager.openNotificationSettings(context);
      return true;
    } catch (_) {
      return false;
    }
  }

  private static async createReminderSlot(): Promise<void> {
    const type = NotificationChannels.reminderSlotType();
    if (type === undefined) return;
    let exists = false;
    try {
      exists = !!(await notificationManager.getSlot(type));
    } catch (_) {}
    if (exists) return;
    try {
      await notificationManager.addSlot(type);
    } catch (_) {
      NotificationChannels.reminderSlotReady = null;
    }
  }
}
