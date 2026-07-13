import { describe, it, expect } from 'vitest';
import packageJson from '../../package.json';
import { exportBackup, validateBackup, mergeImport, overwriteImport } from './backup';
import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';

const LOG_ID_A = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1';
const EMOTION_ID_A = 'c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3';

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
    const result = exportBackup([makeLog(LOG_ID_A)], [makeEmotion(EMOTION_ID_A)], 'notes');
    expect(result.version).toBe('flash-backup-v1');
    expect(result.appVersion).toBe(packageJson.version);
    expect(result.notes).toBe('notes');
    expect(result.logs).toHaveLength(1);
    expect(result.emotions).toHaveLength(1);
    expect(new Date(result.exportedAt).getTime()).not.toBeNaN();
  });
});

describe('validateBackup', () => {
  it('accepts a valid backup', () => {
    const backup = exportBackup([makeLog(LOG_ID_A)], [makeEmotion(EMOTION_ID_A)]);
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
    const backup = exportBackup([makeLog(LOG_ID_A, 'updated')], [makeEmotion(EMOTION_ID_A, 2)]);
    const result = mergeImport(backup, [makeLog(LOG_ID_A, 'old')], [makeEmotion(EMOTION_ID_A, 1)]);
    expect(result.success).toBe(true);
    expect(result.importedLogs).toBe(1);
    expect(result.logs.find((l) => l.id === LOG_ID_A)?.content).toBe('updated');
  });
});

describe('overwriteImport', () => {
  it('replaces all data', () => {
    const backup = exportBackup([makeLog(LOG_ID_A)], [makeEmotion(EMOTION_ID_A)]);
    const result = overwriteImport(backup);
    expect(result.success).toBe(true);
    expect(result.logs).toHaveLength(1);
    expect(result.emotions).toHaveLength(1);
  });

  it('skips logs with invalid id, dates, or level', () => {
    const validLog = makeLog('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1');
    const invalidIdLog = makeLog('not-a-uuid');
    const invalidCreatedAtLog = makeLog('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2');
    invalidCreatedAtLog.createdAt = 'not-a-date';
    const invalidRecordDateLog = makeLog('c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3');
    invalidRecordDateLog.recordDate = 'not-a-date';

    const backup = exportBackup(
      [validLog, invalidIdLog, invalidCreatedAtLog, invalidRecordDateLog],
      []
    );
    const result = overwriteImport(backup);
    expect(result.importedLogs).toBe(1);
    expect(result.skippedLogs).toBe(3);
    expect(result.specificIssues).toContain('3 条日志格式异常，已跳过');
  });

  it('skips emotions with invalid id, level, or dates', () => {
    const validEmotion = makeEmotion('d4d4d4d4-d4d4-d4d4-d4d4-d4d4d4d4d4d4');
    const invalidIdEmotion = makeEmotion('not-a-uuid');
    const invalidLevelEmotion = makeEmotion('e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5');
    invalidLevelEmotion.level = 5 as EmotionRecord['level'];
    const invalidDateEmotion = makeEmotion('f6f6f6f6-f6f6-f6f6-f6f6-f6f6f6f6f6f6');
    invalidDateEmotion.createdAt = 'not-a-date';

    const backup = exportBackup(
      [],
      [validEmotion, invalidIdEmotion, invalidLevelEmotion, invalidDateEmotion]
    );
    const result = overwriteImport(backup);
    expect(result.importedEmotions).toBe(1);
    expect(result.skippedEmotions).toBe(3);
    expect(result.specificIssues).toContain('3 条情绪记录格式异常，已跳过');
  });
});
