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
      colorTag: 'blue' as const,
      category: 'log' as const,
      importance: 0,
      createdAt: '2026-07-14T10:00:00.000Z',
      recordDate: '2026-07-14',
    };
    await storage.saveLog(log);
    expect(await storage.getLogs()).toEqual([log]);
  });
});
