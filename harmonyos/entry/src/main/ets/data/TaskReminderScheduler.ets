// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { TaskItem } from '../models/Models';
import { NotificationChannels } from './NotificationChannels';

const TASK_GROUP = 'flash-aero-tasks';
const ID_STORE_NAME = 'flash-task-reminder-ids';
// Reserved key holding the last allocated notification id. Ids start at 1 and
// stay below the 32-bit positive range the notification service expects.
const COUNTER_KEY = '__counter__';
const MAX_NOTIFICATION_ID = 2147483646;

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
    await NotificationChannels.ensureReminderSlot(context);
    const previous = (await reminderAgentManager.getAllValidReminders())
      .filter((item: reminderAgentManager.ReminderInfo) => item.reminderReq.groupId === TASK_GROUP);
    const idStore = await preferences.getPreferences(context, ID_STORE_NAME);
    const stored = (await idStore.getAll()) as Record<string, number>;
    const counter = typeof stored[COUNTER_KEY] === 'number' ? stored[COUNTER_KEY] : 0;
    // Stable per-task notification ids backed by persistent storage: a hash
    // can collide for two task ids, which would make the second reminder
    // overwrite or fail. The mapping also survives restarts, so a rebuild
    // after reboot reuses the same id for the same task.
    const ids = new Map<string, number>();
    let next = counter;
    const allocate = (taskId: string): number => {
      const existing = ids.get(taskId);
      if (existing !== undefined) return existing;
      next = next >= MAX_NOTIFICATION_ID ? TaskReminderScheduler.firstFree(ids, stored, next) : next + 1;
      ids.set(taskId, next);
      return next;
    };
    // A corrupted Preferences value (wrong type, non-integer, out of range)
    // must behave as if no id was stored: using it as a notificationId could
    // throw mid-publish and leave a half-replaced reminder set.
    const storedId = (taskId: string): number | undefined => {
      const value = stored[taskId];
      if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > MAX_NOTIFICATION_ID) {
        return undefined;
      }
      return value;
    };
    const now = Date.now();
    const slotType = NotificationChannels.reminderSlotType();
    const pending = tasks.filter((task: TaskItem) => {
      if (!task.reminderAt || task.completedAt) return false;
      const reminderDate = new Date(task.reminderAt);
      return Number.isFinite(reminderDate.getTime()) && reminderDate.getTime() > now;
    });
    // Publish every replacement first. If one fails, the previous full set is
    // still present; a later successful rebuild removes the duplicates.
    for (const task of pending) {
      const reminderDate = new Date(task.reminderAt as string);
      const request: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: {
          year: reminderDate.getFullYear(), month: reminderDate.getMonth() + 1, day: reminderDate.getDate(),
          hour: reminderDate.getHours(), minute: reminderDate.getMinutes(), second: reminderDate.getSeconds()
        },
        title: task.title.slice(0, 200),
        content: task.notes?.slice(0, 500) || '任务即将到期',
        expiredContent: task.title.slice(0, 200),
        notificationId: storedId(task.id) ?? allocate(task.id),
        groupId: TASK_GROUP,
        wantAgent: { pkgName: 'com.flash.app.harmonyos', abilityName: 'EntryAbility' },
        ringDuration: 0,
        tapDismissed: true
      };
      if (slotType !== undefined) request.slotType = slotType;
      await reminderAgentManager.publishReminder(request);
    }
    for (const item of previous) {
      await reminderAgentManager.cancelReminder(item.reminderId);
    }
    // Persist the mapping for tasks that still need reminders and drop the
    // rest, so deleted or completed tasks release their ids.
    const keep = new Set<string>(pending.map((task: TaskItem) => task.id));
    for (const key of Object.keys(stored)) {
      if (key !== COUNTER_KEY && !keep.has(key)) await idStore.delete(key);
    }
    for (const task of pending) {
      await idStore.put(task.id, storedId(task.id) ?? allocate(task.id));
    }
    await idStore.put(COUNTER_KEY, next);
    await idStore.flush();
  }

  private static firstFree(ids: Map<string, number>, stored: Record<string, number>, counter: number): number {
    const used = new Set<number>(ids.values());
    // Ids persisted for other tasks are occupied too: reusing one here would
    // make two reminders share a notificationId and overwrite each other.
    for (const key of Object.keys(stored)) {
      if (key === COUNTER_KEY) continue;
      const value = stored[key];
      if (typeof value === 'number' && Number.isInteger(value)) used.add(value);
    }
    for (let candidate = 1; candidate <= counter; candidate++) {
      if (!used.has(candidate)) return candidate;
    }
    return 1;
  }
}
