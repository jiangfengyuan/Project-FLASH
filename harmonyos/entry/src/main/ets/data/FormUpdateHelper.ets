import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { i18n } from '@kit.LocalizationKit';
import { Category, EmotionRecord, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { dayString } from './DateUtils';
import { FlashStore } from './FlashStore';

export const FORM_NAME_TODAY_SUMMARY = 'todaySummary';

const FORM_REGISTRY_PREFERENCES = 'flash-form-registry';
const FORM_REGISTRY_KEY = 'today-summary-form-ids';

export interface TodaySummary {
  records: number;
  ideas: number;
  tasks: number;
}

export type ZoneOffsetResolver = (timeZone: string, instantMs: number) => number | null;

function systemZoneOffset(timeZone: string, instantMs: number): number | null {
  try {
    return i18n.getTimeZone(timeZone).getOffset(instantMs);
  } catch (_) {
    return null;
  }
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function taskLocalDay(task: TaskItem, zoneOffset: ZoneOffsetResolver = systemZoneOffset): string {
  if (task.due.kind === TaskDueKind.ALL_DAY) return task.due.date ?? '';
  if (!task.due.at || !task.due.timeZone) return '';
  const instant = new Date(task.due.at).getTime();
  if (!Number.isFinite(instant)) return '';
  const offset = zoneOffset(task.due.timeZone, instant);
  if (offset === null || !Number.isFinite(offset)) return '';
  const local = new Date(instant + offset);
  return `${local.getUTCFullYear()}-${pad2(local.getUTCMonth() + 1)}-${pad2(local.getUTCDate())}`;
}

export function summarizeToday(
  logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[],
  now: Date = new Date(),
  zoneOffset: ZoneOffsetResolver = systemZoneOffset
): TodaySummary {
  const today = dayString(now);
  const todaysLogs = logs.filter((item: LogItem) => item.recordDate === today);
  const todaysEmotions = emotions.filter((item: EmotionRecord) => item.recordDate === today);
  const pending = tasks.filter((item: TaskItem) =>
    taskLocalDay(item, zoneOffset) === today && (item.completedAt === undefined || item.completedAt === null));
  return {
    records: todaysLogs.length + todaysEmotions.length,
    ideas: todaysLogs.filter((item: LogItem) => item.category === Category.IDEA).length,
    tasks: pending.length
  };
}

export function todaySummaryFormData(summary: TodaySummary): formBindingData.FormBindingData {
  return formBindingData.createFormBindingData({
    records: summary.records,
    ideas: summary.ideas,
    tasks: summary.tasks
  });
}

async function registry(context: common.Context): Promise<preferences.Preferences> {
  return preferences.getPreferences(context, { name: FORM_REGISTRY_PREFERENCES });
}

export async function listTodaySummaryForms(context: common.Context): Promise<string[]> {
  const store = await registry(context);
  const raw = store.getSync(FORM_REGISTRY_KEY, '[]') as string;
  try {
    const parsed = JSON.parse(raw) as string[];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((id: string) => typeof id === 'string' && id.length > 0);
  } catch (_) {
    return [];
  }
}

export async function registerTodaySummaryForm(context: common.Context, formId: string): Promise<void> {
  if (!formId) return;
  const ids = new Set(await listTodaySummaryForms(context));
  ids.add(formId);
  const store = await registry(context);
  await store.put(FORM_REGISTRY_KEY, JSON.stringify(Array.from(ids)));
  await store.flush();
}

export async function unregisterTodaySummaryForm(context: common.Context, formId: string): Promise<void> {
  const ids = (await listTodaySummaryForms(context)).filter((id: string) => id !== formId);
  const store = await registry(context);
  await store.put(FORM_REGISTRY_KEY, JSON.stringify(ids));
  await store.flush();
}

export class FormUpdateHelper {
  static async updateForms(context: common.Context): Promise<number> {
    const formIds = await listTodaySummaryForms(context);
    if (formIds.length === 0) return 0;
    const store = FlashStore.instance;
    await store.initialize(context);
    const data = todaySummaryFormData(summarizeToday(store.logs, store.emotions, store.tasks));
    let updated = 0;
    for (const formId of formIds) {
      try {
        await formProvider.updateForm(formId, data);
        updated++;
      } catch (_) {}
    }
    return updated;
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
