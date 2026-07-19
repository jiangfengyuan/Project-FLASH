import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { SQLiteStorageAdapter } from '../sqliteAdapter';

vi.mock('@capacitor-community/sqlite', () => {
  const mockDb = {
    open: vi.fn().mockResolvedValue(undefined),
    execute: vi.fn().mockResolvedValue(undefined),
    run: vi.fn().mockResolvedValue(undefined),
    query: vi.fn().mockResolvedValue({ values: [] }),
    close: vi.fn().mockResolvedValue(undefined),
  };

  class SQLiteConnectionMock {
    createConnection = vi.fn().mockResolvedValue(mockDb);
  }

  return {
    SQLiteConnection: vi.fn(function () {
      return new SQLiteConnectionMock();
    }),
    CapacitorSQLite: {},
  };
});

describe('SQLiteStorageAdapter', () => {
  let adapter: SQLiteStorageAdapter;

  beforeEach(() => {
    vi.resetModules();
    adapter = new SQLiteStorageAdapter();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('initializes without crashing when mocked', () => {
    // This test primarily documents the contract; real validation happens on device.
    expect(adapter).toBeDefined();
  });

  it('clearAll deletes both tables inside a transaction', async () => {
    await adapter.init();
    const db = (adapter as unknown as { connection: { execute: ReturnType<typeof vi.fn> } })
      .connection;
    db.execute.mockClear();

    await adapter.clearAll();

    expect(db.execute.mock.calls).toEqual([
      ['BEGIN TRANSACTION;'],
      ['DELETE FROM logs;'],
      ['DELETE FROM emotions;'],
      ['COMMIT;'],
    ]);
  });

  it('clearAll rolls back the transaction when a delete fails', async () => {
    await adapter.init();
    const db = (adapter as unknown as { connection: { execute: ReturnType<typeof vi.fn> } })
      .connection;
    db.execute.mockClear();
    db.execute.mockResolvedValueOnce(undefined); // BEGIN TRANSACTION
    db.execute.mockRejectedValueOnce(new Error('delete failed')); // DELETE FROM logs

    await expect(adapter.clearAll()).rejects.toThrow('delete failed');

    expect(db.execute).toHaveBeenCalledWith('BEGIN TRANSACTION;');
    expect(db.execute).toHaveBeenCalledWith('DELETE FROM logs;');
    expect(db.execute).toHaveBeenCalledWith('ROLLBACK;');
    expect(db.execute).not.toHaveBeenCalledWith('COMMIT;');
  });

  it('replaceAll deletes both tables then inserts inside a single transaction', async () => {
    await adapter.init();
    const db = (
      adapter as unknown as {
        connection: { execute: ReturnType<typeof vi.fn>; run: ReturnType<typeof vi.fn> };
      }
    ).connection;
    db.execute.mockClear();
    db.run.mockClear();

    await adapter.replaceAll(
      [
        {
          id: 'log-1',
          content: 'hello',
          colorTag: 'daily',
          category: 'log',
          importance: 0,
          createdAt: '2026-07-14T10:00:00.000Z',
          recordDate: '2026-07-14',
        },
      ],
      [
        {
          id: 'emotion-1',
          level: 1,
          subEmotion: null,
          status: null,
          note: null,
          recordDate: '2026-07-14',
          createdAt: '2026-07-14T10:00:00.000Z',
        },
      ]
    );

    expect(db.execute.mock.calls).toEqual([
      ['BEGIN TRANSACTION;'],
      ['DELETE FROM logs;'],
      ['DELETE FROM emotions;'],
      ['COMMIT;'],
    ]);
    expect(db.run).toHaveBeenCalledTimes(2);
  });

  it('replaceAll rolls back the transaction when an insert fails', async () => {
    await adapter.init();
    const db = (
      adapter as unknown as {
        connection: { execute: ReturnType<typeof vi.fn>; run: ReturnType<typeof vi.fn> };
      }
    ).connection;
    db.execute.mockClear();
    db.run.mockRejectedValueOnce(new Error('insert failed'));

    await expect(
      adapter.replaceAll(
        [
          {
            id: 'log-1',
            content: 'hello',
            colorTag: 'daily',
            category: 'log',
            importance: 0,
            createdAt: '2026-07-14T10:00:00.000Z',
            recordDate: '2026-07-14',
          },
        ],
        []
      )
    ).rejects.toThrow('insert failed');

    expect(db.execute).toHaveBeenCalledWith('BEGIN TRANSACTION;');
    expect(db.execute).toHaveBeenCalledWith('ROLLBACK;');
    expect(db.execute).not.toHaveBeenCalledWith('COMMIT;');
  });
});
