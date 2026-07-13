import { describe, it, expect } from 'vitest';
import { getDailyAverages, getSubEmotionDistribution } from './emotionStats';
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

describe('getDailyAverages', () => {
  it('averages same-day records', () => {
    const result = getDailyAverages([make('2026-07-13', 1), make('2026-07-13', 3)], 7);
    expect(result.find((d) => d.date === '2026-07-13')?.average).toBe(2);
  });

  it('returns empty for no data', () => {
    expect(getDailyAverages([], 7)).toEqual([]);
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
});
