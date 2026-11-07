// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { tr } from './I18n';
import { dayString } from './DateUtils';
import { Category, EmotionRecord, LogItem, TaskItem } from '../models/Models';

export interface MoodSummary {
  average: number;
  emoji: string;
  text: string;
}

export interface WeeklyReport {
  weekStart: string;
  weekEnd: string;
  moments: number;
  ideas: number;
  tasks: number;
  emotions: number;
  mood?: MoodSummary;
  highlights: string[];
  hasData: boolean;
}

export const HIGHLIGHT_LIMIT = 4;
const POSITIVE_THRESHOLD = 1;
const NEGATIVE_THRESHOLD = -1;

function moodSummary(emotions: EmotionRecord[]): MoodSummary | undefined {
  if (emotions.length === 0) return undefined;
  const mean = emotions.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / emotions.length;
  const average = Math.floor(mean * 100 + 0.5) / 100;
  if (average >= POSITIVE_THRESHOLD) return { average: average, emoji: '😊', text: tr('Mostly Positive') };
  if (average <= NEGATIVE_THRESHOLD) return { average: average, emoji: '😔', text: tr('Mostly Low') };
  return { average: average, emoji: '🙂', text: tr('Mostly Steady') };
}

function highlightTitle(item: LogItem): string {
  const first = item.content.split('\n')[0].trim();
  return first === '' ? tr('（无标题）') : first;
}

/**
 * Memory 周报（规则版，无 AI），口径与 FlashCore/Domain/WeeklyMemory.swift 一致：周一到周日的
 * 自然周；日志/灵感/情绪按记录日期，任务按日历日落周。taskDay 由调用方给（含时区换算）。
 */
export function weeklyReport(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[],
  baseDate: Date, taskDay: (task: TaskItem) => string): WeeklyReport {
  const monday = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate());
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  const sunday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6);
  const weekStart = dayString(monday);
  const weekEnd = dayString(sunday);
  const inWeek = (day: string): boolean => day >= weekStart && day <= weekEnd;
  const weekLogs = logs.filter((item: LogItem) => inWeek(item.recordDate));
  const weekEmotions = emotions.filter((item: EmotionRecord) => inWeek(item.recordDate));
  const weekTasks = tasks.filter((item: TaskItem) => {
    const day = taskDay(item);
    return day !== '' && inWeek(day);
  });
  const moments = weekLogs.filter((item: LogItem) => item.category === Category.LOG).length;
  const ideas = weekLogs.filter((item: LogItem) => item.category === Category.IDEA).length;
  const highlights = weekLogs.slice().sort((left: LogItem, right: LogItem) => {
    const leftFavorite = left.isFavorite === true;
    const rightFavorite = right.isFavorite === true;
    if (leftFavorite !== rightFavorite) return leftFavorite ? -1 : 1;
    if (left.importance !== right.importance) return right.importance - left.importance;
    return right.createdAt.localeCompare(left.createdAt);
  }).slice(0, HIGHLIGHT_LIMIT).map(highlightTitle);
  const report: WeeklyReport = {
    weekStart: weekStart,
    weekEnd: weekEnd,
    moments: moments,
    ideas: ideas,
    tasks: weekTasks.length,
    emotions: weekEmotions.length,
    highlights: highlights,
    hasData: moments + ideas + weekTasks.length + weekEmotions.length > 0
  };
  const mood = moodSummary(weekEmotions);
  if (mood !== undefined) report.mood = mood;
  return report;
}
