import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as storageModule from '@/lib/storage';
import { MemoryStorageAdapter } from '@/lib/storage/memoryAdapter';
import { useLogStore, type LogItem } from '@/stores/logStore';
import { DEMO_LOGS } from '@/data/demo';
import { getImportanceFromContent } from '@/lib/constants';

vi.mock('@/lib/storage', async () => {
  const actual = await vi.importActual<typeof storageModule>('@/lib/storage');
  const { MemoryStorageAdapter } = actual;
  return {
    ...actual,
    getStorageAdapter: vi.fn(async () => {
      const adapter = new MemoryStorageAdapter();
      await adapter.init();
      return adapter;
    }),
  };
});

describe('logStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState({ ...useLogStore.getInitialState(), logs: DEMO_LOGS }, true);
  });

  it('adds a log', async () => {
    await useLogStore.getState().addLog('hello', 'daily', 'log');
    const logs = useLogStore.getState().logs;
    expect(logs).toHaveLength(6); // 5 demo + 1 new
    expect(logs[0].content).toBe('hello');
    expect(logs[0].colorTag).toBe('daily');
    expect(logs[0].category).toBe('log');
    expect(logs[0].importance).toBe(0);
  });

  it('updates a log', async () => {
    const id = useLogStore.getState().logs[0].id;
    await useLogStore.getState().updateLog(id, { content: 'updated' });
    expect(useLogStore.getState().logs[0].content).toBe('updated');
  });

  it('deletes a log', async () => {
    const id = useLogStore.getState().logs[0].id;
    await useLogStore.getState().deleteLog(id);
    expect(useLogStore.getState().logs).toHaveLength(4);
  });

  it('filters logs by search query', () => {
    useLogStore.getState().setSearchQuery('AI');
    const filtered = useLogStore.getState().getFilteredLogs();
    expect(filtered.length).toBeGreaterThan(0);
    expect(filtered.every((l) => l.content.toLowerCase().includes('ai'))).toBe(true);
  });

  it('filters logs by tag', () => {
    useLogStore.getState().setFilterTags(['urgent']);
    const filtered = useLogStore.getState().getFilteredLogs();
    expect(filtered.every((l) => l.colorTag === 'urgent')).toBe(true);
  });

  it('moves a log to idea', async () => {
    const id = useLogStore.getState().logs[0].id;
    await useLogStore.getState().moveToIdea(id);
    expect(useLogStore.getState().logs.find((l) => l.id === id)?.category).toBe('idea');
  });

  it('serializes concurrent mutations', async () => {
    class OrderTrackingAdapter extends MemoryStorageAdapter {
      public order: string[] = [];
      async saveLog(log: LogItem): Promise<void> {
        this.order.push(`start-${log.content}`);
        await new Promise((resolve) => setTimeout(resolve, 10));
        this.order.push(`end-${log.content}`);
        await super.saveLog(log);
      }
    }
    const adapter = new OrderTrackingAdapter();
    vi.mocked(storageModule.getStorageAdapter).mockResolvedValue(adapter);

    useLogStore.setState({ ...useLogStore.getInitialState(), logs: [] }, true);

    await Promise.all([
      useLogStore.getState().addLog('first', 'daily', 'log'),
      useLogStore.getState().addLog('second', 'daily', 'log'),
    ]);

    expect(adapter.order).toEqual(['start-first', 'end-first', 'start-second', 'end-second']);
    expect(useLogStore.getState().logs).toHaveLength(2);
  });

  it('flushMutations awaits in-flight mutations', async () => {
    const events: string[] = [];
    class DelayedAdapter extends MemoryStorageAdapter {
      async saveLog(log: LogItem): Promise<void> {
        events.push('save-start');
        await new Promise((resolve) => setTimeout(resolve, 30));
        events.push('save-end');
        await super.saveLog(log);
      }
    }
    vi.mocked(storageModule.getStorageAdapter).mockResolvedValue(new DelayedAdapter());

    useLogStore.setState({ ...useLogStore.getInitialState(), logs: [] }, true);

    const addPromise = useLogStore.getState().addLog('queued', 'daily', 'log');
    await useLogStore.getState().flushMutations();

    expect(events).toEqual(['save-start', 'save-end']);
    expect(useLogStore.getState().logs).toHaveLength(1);
    await addPromise;
  });

  it('flushMutations resolves immediately when queue is idle', async () => {
    await expect(useLogStore.getState().flushMutations()).resolves.toBeUndefined();
  });

  it('parses importance from content', () => {
    expect(getImportanceFromContent('plain')).toBe(0);
    expect(getImportanceFromContent('urgent !!')).toBe(2);
    expect(getImportanceFromContent('very urgent !!!')).toBe(3);
    expect(getImportanceFromContent('critical !!!!')).toBe(4);
  });
});

describe('logStore filters', () => {
  beforeEach(() => {
    useLogStore.setState(
      {
        ...useLogStore.getInitialState(),
        logs: [],
      },
      true
    );
  });

  it('filters by date range', () => {
    const store = useLogStore.getState();
    store.overwriteLogs([
      {
        id: '1',
        content: 'a',
        colorTag: 'daily',
        category: 'log',
        importance: 0,
        createdAt: '2026-07-10T00:00:00Z',
        recordDate: '2026-07-10',
      },
      {
        id: '2',
        content: 'b',
        colorTag: 'daily',
        category: 'log',
        importance: 0,
        createdAt: '2026-07-13T00:00:00Z',
        recordDate: '2026-07-13',
      },
    ]);
    store.setDateRange('2026-07-11', '2026-07-13');
    expect(store.getFilteredLogs()).toHaveLength(1);
  });
});
