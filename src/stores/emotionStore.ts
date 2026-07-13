import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { EmotionLevel, SubEmotion } from '@/lib/constants';
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
  addEmotion: (record: Omit<EmotionRecord, 'id' | 'createdAt'>) => void;
  deleteEmotion: (id: string) => void;
  overwriteEmotions: (emotions: EmotionRecord[]) => void;
  setCurrentLevel: (level: EmotionLevel) => void;
  setCurrentSubEmotion: (sub: SubEmotion) => void;
}

export const useEmotionStore = create<EmotionState>()(
  persist(
    (set) => ({
      emotions: [],
      currentLevel: 1,
      currentSubEmotion: null,
      addEmotion: (record) => {
        const newRecord: EmotionRecord = {
          ...record,
          id: crypto.randomUUID(),
          createdAt: new Date().toISOString(),
        };
        set((state) => ({
          emotions: [newRecord, ...state.emotions],
        }));
      },
      deleteEmotion: (id) => {
        set((state) => ({
          emotions: state.emotions.filter((e) => e.id !== id),
        }));
      },
      overwriteEmotions: (emotions) => set({ emotions }),
      setCurrentLevel: (level) => set({ currentLevel: level }),
      setCurrentSubEmotion: (sub) => set({ currentSubEmotion: sub }),
    }),
    {
      name: 'flash-emotions',
      version: 1,
      partialize: (state) => ({
        emotions: state.emotions,
      }),
    }
  )
);
