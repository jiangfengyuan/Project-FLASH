import { create } from 'zustand';
import type { EmotionLevel, SubEmotion } from '@/lib/constants';
import { getStorageAdapter } from '@/lib/storage';
export type { EmotionLevel, SubEmotion };

export interface EmotionRecord {
  id: string;
  level: EmotionLevel;
  subEmotion: SubEmotion;
  status: string | null;
  note: string | null;
  recordDate: string;
  createdAt: string;
}

interface EmotionState {
  emotions: EmotionRecord[];
  currentLevel: EmotionLevel;
  currentSubEmotion: SubEmotion;
  addEmotion: (record: Omit<EmotionRecord, 'id' | 'createdAt'>) => Promise<void>;
  deleteEmotion: (id: string) => Promise<void>;
  overwriteEmotions: (emotions: EmotionRecord[]) => void;
  setCurrentLevel: (level: EmotionLevel) => void;
  setCurrentSubEmotion: (sub: SubEmotion) => void;
}

async function withStorageRollback(
  mutate: () => void,
  persist: () => Promise<void>,
  rollback: () => void
): Promise<void> {
  mutate();
  try {
    await persist();
  } catch (error) {
    rollback();
    throw error;
  }
}

export const useEmotionStore = create<EmotionState>((set, get) => ({
  emotions: [],
  currentLevel: 1,
  currentSubEmotion: null,
  addEmotion: async (record) => {
    const newRecord: EmotionRecord = {
      ...record,
      id: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
    };
    const previousEmotions = get().emotions;
    await withStorageRollback(
      () => set((state) => ({ emotions: [newRecord, ...state.emotions] })),
      async () => {
        const storage = await getStorageAdapter();
        await storage.saveEmotion(newRecord);
      },
      () => set({ emotions: previousEmotions })
    );
  },
  deleteEmotion: async (id) => {
    const previousEmotions = get().emotions;
    await withStorageRollback(
      () => set((state) => ({ emotions: state.emotions.filter((e) => e.id !== id) })),
      async () => {
        const storage = await getStorageAdapter();
        await storage.deleteEmotion(id);
      },
      () => set({ emotions: previousEmotions })
    );
  },
  overwriteEmotions: (emotions) => set({ emotions }),
  setCurrentLevel: (level) => set({ currentLevel: level }),
  setCurrentSubEmotion: (sub) => set({ currentSubEmotion: sub }),
}));
