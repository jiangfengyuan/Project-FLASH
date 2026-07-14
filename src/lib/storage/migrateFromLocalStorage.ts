import type { StorageAdapter, LogItem, EmotionRecord } from './types';

export const MIGRATION_FLAG_KEY = 'flash-storage-migrated-v1';
const OLD_LOGS_KEY = 'flash-logs';
const OLD_EMOTIONS_KEY = 'flash-emotions';

export async function migrateFromLocalStorage(storage: StorageAdapter): Promise<void> {
  if (typeof window === 'undefined' || !window.localStorage) return;
  if (window.localStorage.getItem(MIGRATION_FLAG_KEY)) return;

  const logs = readOldState<LogItem[]>(OLD_LOGS_KEY, 'logs') ?? [];
  const emotions = readOldState<EmotionRecord[]>(OLD_EMOTIONS_KEY, 'emotions') ?? [];

  if (logs.length === 0 && emotions.length === 0) {
    window.localStorage.setItem(MIGRATION_FLAG_KEY, 'true');
    return;
  }

  try {
    if (logs.length > 0) await storage.saveLogs(logs);
    if (emotions.length > 0) await storage.saveEmotions(emotions);
    window.localStorage.setItem(MIGRATION_FLAG_KEY, 'true');
    window.localStorage.removeItem(OLD_LOGS_KEY);
    window.localStorage.removeItem(OLD_EMOTIONS_KEY);
  } catch (error) {
    console.error('Migration from localStorage failed, will retry on next boot', error);
  }
}

function readOldState<T>(key: string, field: string): T | null {
  const raw = window.localStorage.getItem(key);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as { state?: Record<string, unknown> };
    return (parsed.state?.[field] as T) ?? null;
  } catch {
    return null;
  }
}
