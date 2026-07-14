import type { StorageAdapter, LogItem, EmotionRecord } from './types';

const DB_NAME = 'flash-db';
const DB_VERSION = 1;

export class IndexedDBStorageAdapter implements StorageAdapter {
  private db: IDBDatabase | null = null;

  async init(): Promise<void> {
    if (this.db) return;
    this.db = await openDB();
  }

  async getLogs(): Promise<LogItem[]> {
    const db = await this.ensureDB();
    const tx = db.transaction('logs', 'readonly');
    const store = tx.objectStore('logs');
    const request = store.getAll();
    const rows = (await promisifyRequest(request)) as LogItem[];
    return rows.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }

  async saveLog(log: LogItem): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('logs', 'readwrite');
    tx.objectStore('logs').put(log);
    await promisifyRequest(tx);
  }

  async saveLogs(logs: LogItem[]): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('logs', 'readwrite');
    const store = tx.objectStore('logs');
    for (const log of logs) store.put(log);
    await promisifyRequest(tx);
  }

  async deleteLog(id: string): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('logs', 'readwrite');
    tx.objectStore('logs').delete(id);
    await promisifyRequest(tx);
  }

  async getEmotions(): Promise<EmotionRecord[]> {
    const db = await this.ensureDB();
    const tx = db.transaction('emotions', 'readonly');
    const request = tx.objectStore('emotions').getAll();
    const rows = (await promisifyRequest(request)) as EmotionRecord[];
    return rows.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }

  async saveEmotion(emotion: EmotionRecord): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('emotions', 'readwrite');
    tx.objectStore('emotions').put(emotion);
    await promisifyRequest(tx);
  }

  async saveEmotions(emotions: EmotionRecord[]): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('emotions', 'readwrite');
    const store = tx.objectStore('emotions');
    for (const emotion of emotions) store.put(emotion);
    await promisifyRequest(tx);
  }

  async deleteEmotion(id: string): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction('emotions', 'readwrite');
    tx.objectStore('emotions').delete(id);
    await promisifyRequest(tx);
  }

  async clearAll(): Promise<void> {
    const db = await this.ensureDB();
    const tx = db.transaction(['logs', 'emotions'], 'readwrite');
    tx.objectStore('logs').clear();
    tx.objectStore('emotions').clear();
    await promisifyRequest(tx);
  }

  private async ensureDB(): Promise<IDBDatabase> {
    if (!this.db) await this.init();
    return this.db!;
  }
}

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(toError(request.error));
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = (event) => {
      const db = (event.target as IDBOpenDBRequest).result;
      if (!db.objectStoreNames.contains('logs')) {
        db.createObjectStore('logs', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('emotions')) {
        db.createObjectStore('emotions', { keyPath: 'id' });
      }
    };
  });
}

function promisifyRequest<T>(request: IDBRequest<T> | IDBTransaction): Promise<T> {
  return new Promise((resolve, reject) => {
    if ('onerror' in request && request instanceof IDBTransaction) {
      request.onerror = () => reject(toError(request.error));
      request.oncomplete = () => resolve(undefined as T);
    } else {
      request.onerror = () => reject(toError(request.error));
      request.onsuccess = () => resolve(request.result);
    }
  });
}

function toError(error: DOMException | null): Error {
  return error ?? new Error('IndexedDB request failed');
}
