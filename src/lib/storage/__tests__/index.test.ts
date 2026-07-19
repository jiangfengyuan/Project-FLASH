import { describe, it, expect, beforeEach, vi } from 'vitest';

// Reset the module cache and internal state before each test.
async function resetStorageModule() {
  vi.resetModules();
  // Re-import to get fresh module instances with cleared cachedAdapter/initPromise.
  const mod = await import('../index');
  const { IndexedDBStorageAdapter } = await import('../indexedDBAdapter');
  const { MemoryStorageAdapter } = await import('../memoryAdapter');
  return { mod, IndexedDBStorageAdapter, MemoryStorageAdapter };
}

describe('getStorageAdapterWithMeta', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('reports isFallback=false when default adapter initializes successfully', async () => {
    const { mod } = await resetStorageModule();
    const result = await mod.getStorageAdapterWithMeta();
    expect(result.adapter).toBeDefined();
    expect(result.isFallback).toBe(false);
  });

  it('reports isFallback=true when adapter initialization fails', async () => {
    const { mod, IndexedDBStorageAdapter, MemoryStorageAdapter } = await resetStorageModule();
    vi.spyOn(IndexedDBStorageAdapter.prototype, 'init').mockRejectedValueOnce(
      new Error('init failed')
    );

    const result = await mod.getStorageAdapterWithMeta();
    expect(result.adapter).toBeInstanceOf(MemoryStorageAdapter);
    expect(result.isFallback).toBe(true);
  });

  it('returns the same cached adapter on subsequent calls', async () => {
    const { mod } = await resetStorageModule();
    const first = await mod.getStorageAdapterWithMeta();
    const second = await mod.getStorageAdapterWithMeta();
    expect(second.adapter).toBe(first.adapter);
    expect(second.isFallback).toBe(first.isFallback);
  });
});

describe('getStorageAdapter', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('returns a storage adapter', async () => {
    const { mod } = await resetStorageModule();
    const adapter = await mod.getStorageAdapter();
    expect(adapter).toBeDefined();
    expect(typeof adapter.getLogs).toBe('function');
  });

  it('still falls back to memory adapter internally when init fails', async () => {
    const { mod, IndexedDBStorageAdapter, MemoryStorageAdapter } = await resetStorageModule();
    vi.spyOn(IndexedDBStorageAdapter.prototype, 'init').mockRejectedValueOnce(
      new Error('init failed')
    );

    const result = await mod.getStorageAdapter();
    expect(result).toBeInstanceOf(MemoryStorageAdapter);
  });
});
