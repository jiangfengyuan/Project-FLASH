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
  return {
    SQLiteConnection: vi.fn().mockImplementation(() => ({
      createConnection: vi.fn().mockResolvedValue(mockDb),
    })),
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
});
