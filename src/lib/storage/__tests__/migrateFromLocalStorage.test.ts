import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { MemoryStorageAdapter } from '../memoryAdapter';
import { migrateFromLocalStorage, MIGRATION_FLAG_KEY } from '../migrateFromLocalStorage';

describe('migrateFromLocalStorage', () => {
  let storage: MemoryStorageAdapter;

  beforeEach(() => {
    storage = new MemoryStorageAdapter();
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  it('migrates old Zustand-persisted logs and emotions', async () => {
    await storage.init();
    const oldLog = {
      id: 'log-1',
      content: 'old log',
      colorTag: 'blue' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    const oldEmotion = {
      id: 'emotion-1',
      level: 3 as const,
      subEmotion: 'excited' as const,
      status: 'positive' as const,
      note: 'feeling good',
      recordDate: '2026-07-14',
      createdAt: '2026-07-14T11:00:00.000Z',
    };
    window.localStorage.setItem(
      'flash-logs',
      JSON.stringify({ state: { logs: [oldLog] }, version: 1 })
    );
    window.localStorage.setItem(
      'flash-emotions',
      JSON.stringify({ state: { emotions: [oldEmotion] }, version: 1 })
    );

    await migrateFromLocalStorage(storage);

    expect(await storage.getLogs()).toEqual([oldLog]);
    expect(await storage.getEmotions()).toEqual([oldEmotion]);
    expect(window.localStorage.getItem(MIGRATION_FLAG_KEY)).toBe('true');
    expect(window.localStorage.getItem('flash-logs')).toBeNull();
  });

  it('does nothing when migration flag already set', async () => {
    await storage.init();
    window.localStorage.setItem(MIGRATION_FLAG_KEY, 'true');
    window.localStorage.setItem(
      'flash-logs',
      JSON.stringify({ state: { logs: [{ id: 'log-1' }] }, version: 1 })
    );

    await migrateFromLocalStorage(storage);

    expect(await storage.getLogs()).toEqual([]);
  });

  it('does not overwrite new storage when it already contains data', async () => {
    await storage.init();
    const existingLog = {
      id: 'existing-log',
      content: 'already here',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    const oldLog = {
      id: 'old-log',
      content: 'old log',
      colorTag: 'blue' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T09:00:00.000Z',
      recordDate: '2026-07-14',
    };
    await storage.saveLogs([existingLog]);
    window.localStorage.setItem(
      'flash-logs',
      JSON.stringify({ state: { logs: [oldLog] }, version: 1 })
    );

    await migrateFromLocalStorage(storage);

    expect(await storage.getLogs()).toEqual([existingLog]);
    expect(window.localStorage.getItem(MIGRATION_FLAG_KEY)).toBe('true');
    expect(window.localStorage.getItem('flash-logs')).not.toBeNull();
  });
});
