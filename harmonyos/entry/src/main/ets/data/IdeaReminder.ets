/** PRD 6.3 / Android domain/IdeaReminder.kt：至少积压三条从未查看的灵感才显示提醒。 */
export const IDEA_REMINDER_THRESHOLD = 3;

export function shouldShowIdeaReminder(unviewedCount: number): boolean {
  return unviewedCount >= IDEA_REMINDER_THRESHOLD;
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

export const IDEA_REMINDER_HOUR = 20;

export function ideaReminderIntervalDays(frequency: string): number {
  if (frequency === 'every3days') return 3;
  if (frequency === 'weekly') return 7;
  return 1;
}

/**
 * 下一次灵感提醒的时刻：今天或之后的晚上 8 点，且距上次提醒不少于频率间隔。
 * lastFiredDay 为 yyyy-MM-dd（从未提醒过传空串）。
 */
export function nextIdeaReminderDate(now: Date, frequency: string, lastFiredDay: string): Date {
  const target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), IDEA_REMINDER_HOUR, 0, 0);
  if (target.getTime() <= now.getTime()) target.setDate(target.getDate() + 1);
  if (lastFiredDay !== '') {
    const parts = lastFiredDay.split('-').map((part: string) => Number(part));
    const earliest = new Date(parts[0], parts[1] - 1, parts[2] + ideaReminderIntervalDays(frequency), IDEA_REMINDER_HOUR, 0, 0);
    if (earliest.getTime() > target.getTime()) return earliest;
  }
  return target;
}
