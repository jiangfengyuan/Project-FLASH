import { describe, it, expect } from 'vitest';
import { exportBackup, validateBackup, mergeImport, overwriteImport } from './backup';
import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';

const makeLog = (id: string, content = 'test'): LogItem => ({
  id,
  content,
  colorTag: 'daily',
  category: 'log',
  importance: 0,
  createdAt: '2026-07-13T10:00:00.000Z',
  recordDate: '2026-07-13',
});

const makeEmotion = (id: string, level: EmotionRecord['level'] = 1): EmotionRecord => ({
  id,
  level,
  subEmotion: null,
  status: null,
  note: null,
  recordDate: '2026-07-13',
  createdAt: '2026-07-13T10:00:00.000Z',
});

describe('exportBackup', () => {
  it('returns valid backup shape', () => {
    const result = exportBackup([makeLog('a')], [makeEmotion('b')], 'notes');
    expect(result.version).toBe('flash-backup-v1');
    expect(result.appVersion).toBe('0.1.0');
    expect(result.notes).toBe('notes');
    expect(result.logs).toHaveLength(1);
    expect(result.emotions).toHaveLength(1);
    expect(new Date(result.exportedAt).getTime()).not.toBeNaN();
  });
});

describe('validateBackup', () => {
  it('accepts a valid backup', () => {
    const backup = exportBackup([makeLog('a')], [makeEmotion('b')]);
    expect(validateBackup(backup).valid).toBe(true);
  });

  it('rejects missing version', () => {
    const result = validateBackup({});
    expect(result.valid).toBe(false);
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('rejects unknown fields', () => {
    const backup = exportBackup([], []);
    expect(validateBackup({ ...backup, evil: true }).valid).toBe(false);
  });
});

describe('mergeImport', () => {
  it('overrides same id and keeps local-only records', () => {
    const backup = exportBackup([makeLog('a', 'updated')], [makeEmotion('b', 2)]);
    const result = mergeImport(backup, [makeLog('a', 'old')], [makeEmotion('b', 1)]);
    expect(result.success).toBe(true);
    expect(result.importedLogs).toBe(1);
    expect(result.logs.find((l) => l.id === 'a')?.content).toBe('updated');
  });
});

describe('overwriteImport', () => {
  it('replaces all data', () => {
    const backup = exportBackup([makeLog('a')], [makeEmotion('b')]);
    const result = overwriteImport(backup);
    expect(result.success).toBe(true);
    expect(result.logs).toHaveLength(1);
    expect(result.emotions).toHaveLength(1);
  });
});
