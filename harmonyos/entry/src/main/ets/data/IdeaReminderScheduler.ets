// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { nextIdeaReminderDate, shouldShowIdeaReminder } from './IdeaReminder';
import { NotificationChannels } from './NotificationChannels';
import { tr } from './I18n';

const IDEA_GROUP = 'flash-aero-idea';
const IDEA_NOTIFICATION_ID = 2147480001;

/**
 * 灵感提醒（对齐 iOS）：未读灵感 ≥ 3 时排一个晚上 8 点的日历提醒，只占一个配额；
 * 不满足条件或已关闭时撤销。通知只含数量，不含灵感内容。
 */
export class IdeaReminderScheduler {
  private static queue: Promise<void> = Promise.resolve();
  private static generation: number = 0;
  private static rescheduleRequested: boolean = false;

  /** 返回本次是否排程了新提醒 */
  static sync(context: common.UIAbilityContext, enabled: boolean, unread: number, frequency: string,
    lastFiredDay: string, requestPermission: boolean, reschedule: boolean = false): Promise<boolean> {
    const generation = ++IdeaReminderScheduler.generation;
    IdeaReminderScheduler.rescheduleRequested = IdeaReminderScheduler.rescheduleRequested || reschedule;
    const operation = IdeaReminderScheduler.queue.then(() => IdeaReminderScheduler.performSync(
      context, enabled, unread, frequency, lastFiredDay, requestPermission, generation));
    IdeaReminderScheduler.queue = operation.then(() => {}, () => {});
    return operation;
  }

  private static async performSync(context: common.UIAbilityContext, enabled: boolean, unread: number, frequency: string,
    lastFiredDay: string, requestPermission: boolean, generation: number): Promise<boolean> {
    if (generation !== IdeaReminderScheduler.generation) return false;
    const existing = (await reminderAgentManager.getAllValidReminders())
      .filter((item: reminderAgentManager.ReminderInfo) => item.reminderReq.groupId === IDEA_GROUP);
    if (generation !== IdeaReminderScheduler.generation) return false;
    const due = enabled && shouldShowIdeaReminder(unread);
    if (!due) {
      for (const item of existing) await reminderAgentManager.cancelReminder(item.reminderId);
      if (generation === IdeaReminderScheduler.generation) IdeaReminderScheduler.rescheduleRequested = false;
      return false;
    }
    if (requestPermission) await notificationManager.requestEnableNotification(context);
    if (generation !== IdeaReminderScheduler.generation) return false;
    if (existing.length > 0 && !IdeaReminderScheduler.rescheduleRequested) return false;
    await NotificationChannels.ensureReminderSlot(context);
    if (generation !== IdeaReminderScheduler.generation) return false;
    const when = nextIdeaReminderDate(new Date(), frequency, lastFiredDay);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: when.getFullYear(), month: when.getMonth() + 1, day: when.getDate(),
        hour: when.getHours(), minute: when.getMinutes(), second: 0
      },
      title: tr('想法等待梳理'),
      content: tr('你还有{0}个想法等待梳理，去看看吧', unread),
      notificationId: IDEA_NOTIFICATION_ID,
      groupId: IDEA_GROUP,
      wantAgent: { pkgName: 'com.flash.app.harmonyos', abilityName: 'EntryAbility', parameters: { flashEntry: 'ideas' } },
      ringDuration: 0,
      tapDismissed: true
    };
    const slotType = NotificationChannels.reminderSlotType();
    if (slotType !== undefined) request.slotType = slotType;
    await reminderAgentManager.publishReminder(request);
    // Publish first to retain the previous schedule if the replacement fails.
    // A newer queued disable also sees/removes a publication already in flight.
    for (const item of existing) await reminderAgentManager.cancelReminder(item.reminderId);
    if (generation === IdeaReminderScheduler.generation) IdeaReminderScheduler.rescheduleRequested = false;
    return generation === IdeaReminderScheduler.generation;
  }
}
