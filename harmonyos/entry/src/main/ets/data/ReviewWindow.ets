import { LogItem, EmotionRecord } from '../models/Models';
import { dayString } from './DateUtils';

export function reviewDays(window: string, today: Date = new Date()): string[] {
  let count = 30;
  if (window === 'week') count = (today.getDay() + 6) % 7 + 1;
  else if (window === 'month') count = today.getDate();
  else if (window === '90') count = 90;
  const days: string[] = [];
  for (let offset = 1 - count; offset <= 0; offset++) {
    const date = new Date(today.getTime());
    date.setDate(date.getDate() + offset);
    days.push(dayString(date));
  }
  return days;
}

export interface DailyActivity {
  date: string;
  records: number;
  emotions: number;
  total: number;
}

export function dailyActivity(logs: LogItem[], emotions: EmotionRecord[], days: string[]): DailyActivity[] {
  const recordCounts = new Map<string, number>();
  const emotionCounts = new Map<string, number>();
  logs.forEach((item: LogItem) => recordCounts.set(item.recordDate, (recordCounts.get(item.recordDate) ?? 0) + 1));
  emotions.forEach((item: EmotionRecord) => emotionCounts.set(item.recordDate, (emotionCounts.get(item.recordDate) ?? 0) + 1));
  return days.map((date: string): DailyActivity => {
    const records = recordCounts.get(date) ?? 0;
    const emotionCount = emotionCounts.get(date) ?? 0;
    return { date: date, records: records, emotions: emotionCount, total: records + emotionCount };
  });
}
