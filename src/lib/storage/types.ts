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

  clearAll(): Promise<void>;
}
