import type { LogItem } from '@/stores/logStore';
import type { EmotionRecord } from '@/stores/emotionStore';

export type { LogItem, EmotionRecord };

export interface StorageAdapter {
  init(): Promise<void>;

  getLogs(): Promise<LogItem[]>;
  saveLog(log: LogItem): Promise<void>;
  saveLogs(logs: LogItem[]): Promise<void>;
  deleteLog(id: string): Promise<void>;

  getEmotions(): Promise<EmotionRecord[]>;
  saveEmotion(emotion: EmotionRecord): Promise<void>;
  saveEmotions(emotions: EmotionRecord[]): Promise<void>;
  deleteEmotion(id: string): Promise<void>;

  /**
   * Atomically replaces the entire contents of both stores with the given
   * records. Unlike saveLogs/saveEmotions (upsert-only), this removes any
   * pre-existing records that are not part of the payload.
   */
  replaceAll(logs: LogItem[], emotions: EmotionRecord[]): Promise<void>;

  clearAll(): Promise<void>;
}
