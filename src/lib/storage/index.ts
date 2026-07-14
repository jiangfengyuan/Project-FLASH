import { Capacitor } from '@capacitor/core';
import type { StorageAdapter } from './types';
import { MemoryStorageAdapter } from './memoryAdapter';
import { IndexedDBStorageAdapter } from './indexedDBAdapter';
import { SQLiteStorageAdapter } from './sqliteAdapter';

export type { StorageAdapter } from './types';
export { MemoryStorageAdapter } from './memoryAdapter';
export { IndexedDBStorageAdapter } from './indexedDBAdapter';
export { SQLiteStorageAdapter } from './sqliteAdapter';
import { migrateFromLocalStorage, MIGRATION_FLAG_KEY } from './migrateFromLocalStorage';
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

export async function getStorageAdapter(): Promise<StorageAdapter> {
  if (cachedAdapter) return cachedAdapter;
  if (initPromise) return initPromise;

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

  return initPromise;
}
