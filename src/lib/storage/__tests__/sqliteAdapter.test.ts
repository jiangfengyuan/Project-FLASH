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
});
