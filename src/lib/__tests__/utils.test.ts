import { describe, expect, it } from 'vitest';
import { getTodayStr, parseLocalDate } from '@/lib/utils';

describe('utils', () => {
  describe('getTodayStr', () => {
    it('returns YYYY-MM-DD for the given date', () => {
      const date = new Date(2026, 5, 20); // June 20, 2026
      expect(getTodayStr(date)).toBe('2026-06-20');
    });
  });

  describe('parseLocalDate', () => {
    it('parses YYYY-MM-DD without timezone shift', () => {
      const parsed = parseLocalDate('2026-06-20');
      expect(parsed.getFullYear()).toBe(2026);
      expect(parsed.getMonth()).toBe(5);
      expect(parsed.getDate()).toBe(20);
    });
  });
});
