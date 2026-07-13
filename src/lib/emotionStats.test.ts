import { describe, it, expect, vi, afterEach } from 'vitest';
import { format, subDays } from 'date-fns';
import { getDailyAverages, getSubEmotionDistribution, hasEmotionData } from './emotionStats';
import type { EmotionRecord } from '@/stores/emotionStore';

const make = (
  recordDate: string,
  level: number,
  subEmotion: EmotionRecord['subEmotion'] = null
): EmotionRecord => ({
  id: recordDate + level,
  level: level as EmotionRecord['level'],
  subEmotion,
  status: null,
  note: null,
  recordDate,
  createdAt: `${recordDate}T10:00:00Z`,
});

afterEach(() => {
  vi.useRealTimers();
});

describe('getDailyAverages', () => {
  it('averages same-day records', () => {
    const result = getDailyAverages([make('2026-07-13', 1), make('2026-07-13', 3)], 7);
    expect(result.find((d) => d.date === '2026-07-13')?.average).toBe(2);
  });

  it('returns empty for no data', () => {
    expect(getDailyAverages([], 7)).toEqual([]);
  });

  it('includes records on the first day of the window regardless of time of day', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-13T12:00:00'));

    const startStr = format(subDays(new Date(), 6), 'yyyy-MM-dd');
    const result = getDailyAverages([make(startStr, 2)], 7);
    const day = result.find((d) => d.date === startStr);
    expect(day?.average).toBe(2);
  });

  it('includes records on the last day of the window regardless of time of day', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-13T12:00:00'));

    const todayStr = format(new Date(), 'yyyy-MM-dd');
    const result = getDailyAverages([make(todayStr, 3)], 7);
    const day = result.find((d) => d.date === todayStr);
    expect(day?.average).toBe(3);
  });
});

describe('getSubEmotionDistribution', () => {
  it('counts negative sub-emotions only', () => {
    const result = getSubEmotionDistribution(
      [
        make('2026-07-13', -2, 'sad'),
        make('2026-07-13', -1, 'angry'),
        make('2026-07-13', 2, 'sad'),
      ],
      7
    );
    const sad = result.find((r) => r.name === '伤心');
    const angry = result.find((r) => r.name === '生气');
    expect(sad?.count).toBe(1);
    expect(angry?.count).toBe(1);
  });

  it('includes sub-emotions on the first day of the window regardless of time of day', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-13T12:00:00'));

    const startStr = format(subDays(new Date(), 6), 'yyyy-MM-dd');
    const result = getSubEmotionDistribution([make(startStr, -2, 'sad')], 7);
    const sad = result.find((r) => r.name === '伤心');
    expect(sad?.count).toBe(1);
  });
});

describe('hasEmotionData', () => {
  it('returns false when there are no records', () => {
    expect(hasEmotionData([], 7)).toBe(false);
  });

  it('returns true for a record on the first day of the window regardless of time of day', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-13T12:00:00'));

    const startStr = format(subDays(new Date(), 6), 'yyyy-MM-dd');
    expect(hasEmotionData([make(startStr, 2)], 7)).toBe(true);
  });

  it('returns false for a record before the window', () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-07-13T12:00:00'));

    const beforeStr = format(subDays(new Date(), 7), 'yyyy-MM-dd');
    expect(hasEmotionData([make(beforeStr, 2)], 7)).toBe(false);
  });
});
