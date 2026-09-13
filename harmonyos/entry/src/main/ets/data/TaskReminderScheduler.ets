// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { TaskItem } from '../models/Models';

const TASK_GROUP = 'flash-aero-tasks';

/** Rebuilds this application's one-shot task reminders from the durable task store. */
export class TaskReminderScheduler {
  private static queue: Promise<void> = Promise.resolve(undefined);

  static rebuild(context: common.UIAbilityContext, tasks: TaskItem[], requestPermission: boolean): Promise<void> {
    const operation = TaskReminderScheduler.queue.then(() =>
      TaskReminderScheduler.performRebuild(context, tasks, requestPermission));
    TaskReminderScheduler.queue = operation.catch(() => {});
    return operation;
  }

  private static async performRebuild(context: common.UIAbilityContext, tasks: TaskItem[],
    requestPermission: boolean): Promise<void> {
    if (requestPermission) await notificationManager.requestEnableNotification(context);
    const previous = (await reminderAgentManager.getAllValidReminders())
      .filter((item: reminderAgentManager.ReminderInfo) => item.reminderReq.groupId === TASK_GROUP);
    const now = Date.now();
    // Publish every replacement first. If one fails, the previous full set is
    // still present; a later successful rebuild removes the duplicates.
    for (const task of tasks) {
      if (!task.reminderAt || task.completedAt) continue;
      const reminderDate = new Date(task.reminderAt);
      if (!Number.isFinite(reminderDate.getTime()) || reminderDate.getTime() <= now) continue;
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: {
          year: reminderDate.getFullYear(), month: reminderDate.getMonth() + 1, day: reminderDate.getDate(),
          hour: reminderDate.getHours(), minute: reminderDate.getMinutes(), second: reminderDate.getSeconds()
        },
        title: task.title.slice(0, 200),
        content: task.notes?.slice(0, 500) || '任务即将到期',
        expiredContent: task.title.slice(0, 200),
        notificationId: TaskReminderScheduler.notificationId(task.id),
        groupId: TASK_GROUP,
        wantAgent: { pkgName: 'com.flash.app.harmonyos', abilityName: 'EntryAbility' },
        ringDuration: 0,
        tapDismissed: true
      };
      await reminderAgentManager.publishReminder(request);
    }
    for (const item of previous) {
      await reminderAgentManager.cancelReminder(item.reminderId);
    }
  }

  private static notificationId(id: string): number {
    let hash = 2166136261;
    for (let index = 0; index < id.length; index++) {
      hash ^= id.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return Math.abs(hash % 2147483646) + 1;
  }
}
