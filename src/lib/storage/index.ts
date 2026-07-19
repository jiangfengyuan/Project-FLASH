import { Capacitor } from '@capacitor/core';
import type { StorageAdapter } from './types';
import { MemoryStorageAdapter } from './memoryAdapter';
import { IndexedDBStorageAdapter } from './indexedDBAdapter';
import { SQLiteStorageAdapter } from './sqliteAdapter';
import { migrateFromLocalStorage, MIGRATION_FLAG_KEY } from './migrateFromLocalStorage';

export type { StorageAdapter } from './types';
export { MemoryStorageAdapter } from './memoryAdapter';
export { IndexedDBStorageAdapter } from './indexedDBAdapter';
export { SQLiteStorageAdapter } from './sqliteAdapter';
export { migrateFromLocalStorage, MIGRATION_FLAG_KEY };

let cachedAdapter: StorageAdapter | null = null;
let initPromise: Promise<StorageAdapter> | null = null;

export function createStorageAdapter(): StorageAdapter {
  if (Capacitor.isNativePlatform()) {
    return new SQLiteStorageAdapter();
  }
  if (typeof window !== 'undefined' && window.indexedDB) {
    return new IndexedDBStorageAdapter();
  }
  return new MemoryStorageAdapter();
}

export async function getStorageAdapterWithMeta(): Promise<{
  adapter: StorageAdapter;
  isFallback: boolean;
}> {
  if (cachedAdapter) {
    return { adapter: cachedAdapter, isFallback: cachedAdapter instanceof MemoryStorageAdapter };
  }
  if (initPromise) {
    const adapter = await initPromise;
    return { adapter, isFallback: adapter instanceof MemoryStorageAdapter };
  }

  initPromise = (async () => {
    let adapter = createStorageAdapter();
    try {
      await adapter.init();
      await migrateFromLocalStorage(adapter);
    } catch (error) {
      console.error('Storage initialization failed, falling back to memory adapter', error);
      adapter = new MemoryStorageAdapter();
      await adapter.init();
    }
    cachedAdapter = adapter;
    return adapter;
  })();

  const adapter = await initPromise;
  return { adapter, isFallback: adapter instanceof MemoryStorageAdapter };
}

export async function getStorageAdapter(): Promise<StorageAdapter> {
  const { adapter } = await getStorageAdapterWithMeta();
  return adapter;
}
