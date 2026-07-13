import type { EmotionRecord, SubEmotion } from '@/stores/emotionStore';
import { subDays, format, parseISO, isAfter } from 'date-fns';

const SUB_EMOTION_NAMES: Record<NonNullable<SubEmotion>, string> = {
  sad: '伤心',
  angry: '生气',
  uncomfortable: '难受',
};

export function getDailyAverages(emotions: EmotionRecord[], days: number) {
  const end = new Date();
  const start = subDays(end, days - 1);
  const filtered = emotions.filter((e) => {
    const d = parseISO(e.recordDate);
    return d >= start && d <= end;
  });

  if (filtered.length === 0) return [];

  const grouped = new Map<string, number[]>();
  for (const e of filtered) {
    const list = grouped.get(e.recordDate) ?? [];
    list.push(e.level);
    grouped.set(e.recordDate, list);
  }

  const result: { date: string; average: number }[] = [];
  for (let i = 0; i < days; i++) {
    const date = format(subDays(end, days - 1 - i), 'yyyy-MM-dd');
    const levels = grouped.get(date);
    const average = levels ? levels.reduce((a, b) => a + b, 0) / levels.length : 0;
    result.push({ date, average: Number(average.toFixed(2)) });
  }
  return result;
}

export function getSubEmotionDistribution(emotions: EmotionRecord[], days: number) {
  const end = new Date();
  const start = subDays(end, days - 1);
  const counts = new Map<string, number>();

  for (const e of emotions) {
    const d = parseISO(e.recordDate);
    if (e.level >= 0 || !e.subEmotion) continue;
    if (isAfter(start, d) || isAfter(d, end)) continue;
    const name = SUB_EMOTION_NAMES[e.subEmotion];
    counts.set(name, (counts.get(name) ?? 0) + 1);
  }

  return Array.from(counts.entries()).map(([name, count]) => ({ name, count }));
}
