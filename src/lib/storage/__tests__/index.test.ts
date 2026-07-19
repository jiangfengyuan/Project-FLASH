import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  getStorageAdapter,
  getStorageAdapterWithMeta,
  createStorageAdapter,
} from '../index';
import { MemoryStorageAdapter } from '../memoryAdapter';

// Reset the module cache and internal state before each test.
async function resetStorageModule() {
  vi.resetModules();
  // Re-import to get a fresh module instance with cleared cachedAdapter/initPromise.
  const mod = await import('../index');
  return mod;
}

describe('getStorageAdapterWithMeta', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('reports isFallback=false when default adapter initializes successfully', async () => {
    const mod = await resetStorageModule();
    const result = await mod.getStorageAdapterWithMeta();
    expect(result.adapter).toBeDefined();
    expect(result.isFallback).toBe(false);
  });

  it('reports isFallback=true when adapter initialization fails', async () => {
    const mod = await resetStorageModule();
    const adapter = mod.createStorageAdapter();
    vi.spyOn(adapter, 'init').mockRejectedValueOnce(new Error('init failed'));
    vi.spyOn(mod, 'createStorageAdapter').mockReturnValueOnce(adapter);

    const result = await mod.getStorageAdapterWithMeta();
    expect(result.adapter).toBeInstanceOf(MemoryStorageAdapter);
    expect(result.isFallback).toBe(true);
  });

  it('returns the same cached adapter on subsequent calls', async () => {
    const mod = await resetStorageModule();
    const first = await mod.getStorageAdapterWithMeta();
    const second = await mod.getStorageAdapterWithMeta();
    expect(second.adapter).toBe(first.adapter);
    expect(second.isFallback).toBe(first.isFallback);
  });
});

describe('getStorageAdapter', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns a storage adapter', async () => {
    const mod = await resetStorageModule();
    const adapter = await mod.getStorageAdapter();
    expect(adapter).toBeDefined();
    expect(typeof adapter.getLogs).toBe('function');
  });

  it('still falls back to memory adapter internally when init fails', async () => {
    const mod = await resetStorageModule();
    const adapter = mod.createStorageAdapter();
    vi.spyOn(adapter, 'init').mockRejectedValueOnce(new Error('init failed'));
    vi.spyOn(mod, 'createStorageAdapter').mockReturnValueOnce(adapter);

    const result = await mod.getStorageAdapter();
    expect(result).toBeInstanceOf(MemoryStorageAdapter);
  });
});
