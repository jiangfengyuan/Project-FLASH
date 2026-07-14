/* eslint-disable @typescript-eslint/require-await --
   MemoryStorageAdapter is a synchronous in-memory implementation of the async
   StorageAdapter interface. The methods must return Promises to satisfy the
   interface, but they perform no real I/O, so they legitimately contain no
   await expressions. */
import type { StorageAdapter, LogItem, EmotionRecord } from './types';

export class MemoryStorageAdapter implements StorageAdapter {
  private logs = new Map<string, LogItem>();
  private emotions = new Map<string, EmotionRecord>();
  private initialized = false;

  async init(): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;
  }

  async getLogs(): Promise<LogItem[]> {
    return Array.from(this.logs.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  async saveLog(log: LogItem): Promise<void> {
    this.logs.set(log.id, log);
  }

  async saveLogs(logs: LogItem[]): Promise<void> {
    for (const log of logs) this.logs.set(log.id, log);
  }

  async deleteLog(id: string): Promise<void> {
    this.logs.delete(id);
  }

  async getEmotions(): Promise<EmotionRecord[]> {
    return Array.from(this.emotions.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  async saveEmotion(emotion: EmotionRecord): Promise<void> {
    this.emotions.set(emotion.id, emotion);
  }

  async saveEmotions(emotions: EmotionRecord[]): Promise<void> {
    for (const emotion of emotions) this.emotions.set(emotion.id, emotion);
  }

  async deleteEmotion(id: string): Promise<void> {
    this.emotions.delete(id);
  }

  async clearAll(): Promise<void> {
    this.logs.clear();
    this.emotions.clear();
  }
}
