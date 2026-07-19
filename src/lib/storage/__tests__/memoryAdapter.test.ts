import { describe, it, expect, beforeEach } from 'vitest';
import { MemoryStorageAdapter } from '../memoryAdapter';

describe('MemoryStorageAdapter', () => {
  let storage: MemoryStorageAdapter;

  beforeEach(() => {
    storage = new MemoryStorageAdapter();
  });

  it('initializes with empty data', async () => {
    await storage.init();
    expect(await storage.getLogs()).toEqual([]);
    expect(await storage.getEmotions()).toEqual([]);
  });

  it('saves and retrieves a log', async () => {
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
    expect(await storage.getLogs()).toEqual([log]);
  });

  it('replaceAll removes old records and stores only the new payload', async () => {
    await storage.init();
    const oldLog = {
      id: 'log-old',
      content: 'old',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-13T10:00:00.000Z',
      recordDate: '2026-07-13',
    };
    const oldEmotion = {
      id: 'emotion-old',
      level: 1 as const,
      subEmotion: null,
      status: null,
      note: null,
      recordDate: '2026-07-13',
      createdAt: '2026-07-13T10:00:00.000Z',
    };
    await storage.saveLog(oldLog);
    await storage.saveEmotion(oldEmotion);

    const newLog = { ...oldLog, id: 'log-new', content: 'new' };
    const newEmotion = { ...oldEmotion, id: 'emotion-new' };
    await storage.replaceAll([newLog], [newEmotion]);

    expect(await storage.getLogs()).toEqual([newLog]);
    expect(await storage.getEmotions()).toEqual([newEmotion]);
  });

  it('replaceAll with empty arrays clears both stores', async () => {
    await storage.init();
    await storage.saveLog({
      id: 'log-1',
      content: 'hello',
      colorTag: 'daily' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    });
    await storage.replaceAll([], []);
    expect(await storage.getLogs()).toEqual([]);
    expect(await storage.getEmotions()).toEqual([]);
  });
});
