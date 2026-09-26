import { LogItem, EmotionRecord, subEmotionName } from '../models/Models';
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

// 当前窗口与前一等长窗口的对比：洞察卡「先结论后数据」。
export interface ReviewComparison {
  currentLabel: string;
  previousLabel: string;
  currentCount: number;
  previousCount: number;
  currentEmotionAvg: number | null;
  previousEmotionAvg: number | null;
  insufficient: boolean;
  conclusion: string;
}

function windowLabels(window: string): string[] {
  if (window === 'week') return ['这周', '上周'];
  if (window === 'month') return ['这个月', '上个月'];
  if (window === '90') return ['近 90 天', '之前 90 天'];
  return ['近 30 天', '之前 30 天'];
}

function previousDays(count: number, today: Date): string[] {
  const days: string[] = [];
  for (let offset = 1 - 2 * count; offset <= -count; offset++) {
    const date = new Date(today.getTime());
    date.setDate(date.getDate() + offset);
    days.push(dayString(date));
  }
  return days;
}

function countInDays(dates: string[], days: string[]): number {
  return dates.filter((date: string) => days.includes(date)).length;
}

function averageLevel(emotions: EmotionRecord[], days: string[]): number | null {
  const inWindow = emotions.filter((item: EmotionRecord) => days.includes(item.recordDate));
  if (inWindow.length === 0) return null;
  return inWindow.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / inWindow.length;
}

export function reviewComparison(logs: LogItem[], emotions: EmotionRecord[], window: string,
  today: Date = new Date()): ReviewComparison {
  const current = reviewDays(window, today);
  const previous = previousDays(current.length, today);
  const labels = windowLabels(window);
  const currentCount = countInDays(logs.map((item: LogItem) => item.recordDate), current) +
    countInDays(emotions.map((item: EmotionRecord) => item.recordDate), current);
  const previousCount = countInDays(logs.map((item: LogItem) => item.recordDate), previous) +
    countInDays(emotions.map((item: EmotionRecord) => item.recordDate), previous);
  const currentEmotionAvg = averageLevel(emotions, current);
  const previousEmotionAvg = averageLevel(emotions, previous);
  const currentEmotions = countInDays(emotions.map((item: EmotionRecord) => item.recordDate), current);
  const previousEmotions = countInDays(emotions.map((item: EmotionRecord) => item.recordDate), previous);

  const insufficient = currentCount + previousCount < 5;
  let conclusion: string;
  if (insufficient) {
    conclusion = '继续记录，回顾会慢慢清晰';
  } else if (currentCount > previousCount) {
    conclusion = `${labels[0]}你记录得比${labels[1]}更频繁`;
  } else if (currentCount < previousCount) {
    conclusion = `${labels[0]}不如${labels[1]}活跃`;
  } else {
    conclusion = `${labels[0]}与${labels[1]}持平`;
  }
  if (!insufficient && currentEmotionAvg !== null && previousEmotionAvg !== null &&
    currentEmotions >= 2 && previousEmotions >= 2) {
    const diff = currentEmotionAvg - previousEmotionAvg;
    if (diff >= 1) conclusion += '，情绪整体更积极了一些';
    else if (diff <= -1) conclusion += '，情绪整体低落了一些';
  }
  return {
    currentLabel: labels[0],
    previousLabel: labels[1],
    currentCount: currentCount,
    previousCount: previousCount,
    currentEmotionAvg: currentEmotionAvg,
    previousEmotionAvg: previousEmotionAvg,
    insufficient: insufficient,
    conclusion: conclusion
  };
}

// 时间窗口内的情绪分布：正/中性/负向计数与负向子情绪构成。
export interface SubEmotionSlice {
  key: string;
  name: string;
  count: number;
}

export interface EmotionDistribution {
  positive: number;
  neutral: number;
  negative: number;
  total: number;
  subEmotions: SubEmotionSlice[];
}

export function emotionDistribution(emotions: EmotionRecord[], days: string[]): EmotionDistribution {
  const inWindow = emotions.filter((item: EmotionRecord) => days.includes(item.recordDate));
  const slices = new Map<string, number>();
  let positive = 0;
  let neutral = 0;
  let negative = 0;
  inWindow.forEach((item: EmotionRecord) => {
    if (item.level > 0) positive++;
    else if (item.level < 0) {
      negative++;
      if (item.subEmotion) slices.set(item.subEmotion, (slices.get(item.subEmotion) ?? 0) + 1);
    } else neutral++;
  });
  const subEmotions: SubEmotionSlice[] = [];
  slices.forEach((count: number, key: string) => {
    subEmotions.push({ key: key, name: subEmotionName(key) || key, count: count });
  });
  subEmotions.sort((a: SubEmotionSlice, b: SubEmotionSlice) => b.count - a.count);
  return {
    positive: positive,
    neutral: neutral,
    negative: negative,
    total: inWindow.length,
    subEmotions: subEmotions
  };
}
