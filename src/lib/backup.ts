import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';
import packageJson from '../../package.json';

export const APP_VERSION = packageJson.version;
export const BACKUP_VERSION = 'flash-backup-v1';
export const MAX_BACKUP_SIZE_BYTES = 10 * 1024 * 1024;

export interface FlashBackup {
  version: string;
  exportedAt: string;
  appVersion: string;
  notes: string;
  logs: LogItem[];
  emotions: EmotionRecord[];
}

export interface ImportResult {
  success: boolean;
  logs: LogItem[];
  emotions: EmotionRecord[];
  importedLogs: number;
  importedEmotions: number;
  skippedLogs: number;
  skippedEmotions: number;
  specificIssues: string[];
}

const ALLOWED_KEYS: (keyof FlashBackup)[] = [
  'version',
  'exportedAt',
  'appVersion',
  'notes',
  'logs',
  'emotions',
];

export function exportBackup(logs: LogItem[], emotions: EmotionRecord[], notes = ''): FlashBackup {
  return {
    version: BACKUP_VERSION,
    exportedAt: new Date().toISOString(),
    appVersion: APP_VERSION,
    notes,
    logs,
    emotions,
  };
}

export function validateBackup(data: unknown): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (data === null || typeof data !== 'object') {
    errors.push('备份文件不是有效的 JSON 对象');
    return { valid: false, errors };
  }

  const backup = data as Record<string, unknown>;

  const unknownKeys = Object.keys(backup).filter(
    (key) => !ALLOWED_KEYS.includes(key as keyof FlashBackup)
  );
  if (unknownKeys.length > 0) {
    errors.push(`包含未知字段：${unknownKeys.join(', ')}`);
  }

  if (backup.version !== BACKUP_VERSION) {
    errors.push(`备份版本不兼容：期望 ${BACKUP_VERSION}，实际 ${String(backup.version)}`);
  }

  if (typeof backup.exportedAt !== 'string' || Number.isNaN(Date.parse(backup.exportedAt))) {
    errors.push('exportedAt 不是有效的时间字符串');
  }

  if (typeof backup.appVersion !== 'string') {
    errors.push('appVersion 必须是字符串');
  }

  if (typeof backup.notes !== 'string') {
    errors.push('notes 必须是字符串');
  }

  if (!Array.isArray(backup.logs)) {
    errors.push('logs 必须是数组');
  }

  if (!Array.isArray(backup.emotions)) {
    errors.push('emotions 必须是数组');
  }

  return { valid: errors.length === 0, errors };
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_REGEX.test(value);
}

function isValidIsoDate(value: unknown): value is string {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
}

function isValidRecordDate(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function isValidEmotionLevel(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= -3 && value <= 3;
}

function isValidLog(item: unknown): item is LogItem {
  if (typeof item !== 'object' || item === null) return false;
  const log = item as Partial<LogItem>;
  return (
    isValidUuid(log.id) &&
    typeof log.content === 'string' &&
    typeof log.colorTag === 'string' &&
    typeof log.category === 'string' &&
    isValidIsoDate(log.createdAt) &&
    isValidRecordDate(log.recordDate)
  );
}

function isValidEmotion(item: unknown): item is EmotionRecord {
  if (typeof item !== 'object' || item === null) return false;
  const e = item as Partial<EmotionRecord>;
  return (
    isValidUuid(e.id) &&
    isValidEmotionLevel(e.level) &&
    isValidRecordDate(e.recordDate) &&
    isValidIsoDate(e.createdAt)
  );
}

export function sanitizeBackup(backup: FlashBackup): ImportResult {
  const logs: LogItem[] = [];
  const emotions: EmotionRecord[] = [];
  const specificIssues: string[] = [];
  let skippedLogs = 0;
  let skippedEmotions = 0;

  for (const item of backup.logs) {
    if (isValidLog(item)) {
      logs.push(item);
    } else {
      skippedLogs += 1;
    }
  }

  for (const item of backup.emotions) {
    if (isValidEmotion(item)) {
      emotions.push(item);
    } else {
      skippedEmotions += 1;
    }
  }

  if (skippedLogs > 0) {
    specificIssues.push(`${skippedLogs} 条日志格式异常，已跳过`);
  }
  if (skippedEmotions > 0) {
    specificIssues.push(`${skippedEmotions} 条情绪记录格式异常，已跳过`);
  }

  return {
    success: true,
    logs,
    emotions,
    importedLogs: logs.length,
    importedEmotions: emotions.length,
    skippedLogs,
    skippedEmotions,
    specificIssues,
  };
}

export function mergeImport(
  backup: FlashBackup,
  currentLogs: LogItem[],
  currentEmotions: EmotionRecord[]
): ImportResult {
  const sanitized = sanitizeBackup(backup);
  const logMap = new Map(currentLogs.map((l) => [l.id, l]));
  for (const log of sanitized.logs) {
    logMap.set(log.id, log);
  }
  const emotionMap = new Map(currentEmotions.map((e) => [e.id, e]));
  for (const emotion of sanitized.emotions) {
    emotionMap.set(emotion.id, emotion);
  }
  return {
    ...sanitized,
    logs: Array.from(logMap.values()),
    emotions: Array.from(emotionMap.values()),
  };
}

export function overwriteImport(backup: FlashBackup): ImportResult {
  const sanitized = sanitizeBackup(backup);
  return {
    ...sanitized,
    logs: sanitized.logs,
    emotions: sanitized.emotions,
  };
}
