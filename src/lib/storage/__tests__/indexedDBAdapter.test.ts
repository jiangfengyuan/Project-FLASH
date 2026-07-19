import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { IndexedDBStorageAdapter } from '../indexedDBAdapter';

describe('IndexedDBStorageAdapter', () => {
  let storage: IndexedDBStorageAdapter;

  beforeEach(() => {
    storage = new IndexedDBStorageAdapter();
  });

  afterEach(async () => {
    await storage.clearAll();
  });

  it('initializes with empty data', async () => {
    await storage.init();
    expect(await storage.getLogs()).toEqual([]);
    expect(await storage.getEmotions()).toEqual([]);
  });

  it('persists logs across adapter instances', async () => {
    await storage.init();
    const log = {
      id: 'log-1',
      content: 'hello',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    await storage.saveLog(log);

    const second = new IndexedDBStorageAdapter();
    await second.init();
    expect(await second.getLogs()).toEqual([log]);
  });

  it('deletes a log', async () => {
    await storage.init();
    const log = {
      id: 'log-1',
      content: 'hello',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    await storage.saveLog(log);
    await storage.deleteLog(log.id);
    expect(await storage.getLogs()).toEqual([]);
  });

  it('saves and retrieves emotions', async () => {
    await storage.init();
    const emotion = {
      id: 'emotion-1',
      level: 3 as const,
      subEmotion: 'sad' as const,
      status: 'stable',
      note: 'feeling good',
      recordDate: '2026-07-14',
      createdAt: '2026-07-14T10:00:00.000Z',
    };
    await storage.saveEmotion(emotion);
    expect(await storage.getEmotions()).toEqual([emotion]);
  });

  it('deletes an emotion', async () => {
    await storage.init();
    const emotion = {
      id: 'emotion-1',
      level: 3 as const,
      subEmotion: 'sad' as const,
      status: 'stable',
      note: 'feeling good',
      recordDate: '2026-07-14',
      createdAt: '2026-07-14T10:00:00.000Z',
    };
    await storage.saveEmotion(emotion);
    await storage.deleteEmotion(emotion.id);
    expect(await storage.getEmotions()).toEqual([]);
  });

  it('replaceAll removes old records and persists across adapter instances', async () => {
    await storage.init();
    await storage.saveLog({
      id: 'log-old',
      content: 'old',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-13T10:00:00.000Z',
      recordDate: '2026-07-13',
    });
    await storage.saveEmotion({
      id: 'emotion-old',
      level: 1 as const,
      subEmotion: null,
      status: null,
      note: null,
      recordDate: '2026-07-13',
      createdAt: '2026-07-13T10:00:00.000Z',
    });

    const newLog = {
      id: 'log-new',
      content: 'new',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    const newEmotion = {
      id: 'emotion-new',
      level: 2 as const,
      subEmotion: null,
      status: null,
      note: null,
      recordDate: '2026-07-14',
      createdAt: '2026-07-14T10:00:00.000Z',
    };
    await storage.replaceAll([newLog], [newEmotion]);

    const second = new IndexedDBStorageAdapter();
    await second.init();
    expect(await second.getLogs()).toEqual([newLog]);
    expect(await second.getEmotions()).toEqual([newEmotion]);
  });
});
