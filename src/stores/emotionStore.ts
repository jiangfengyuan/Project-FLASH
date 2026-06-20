import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { EmotionLevel, SubEmotion } from '@/lib/constants';
import { getTodayStr } from '@/lib/utils';
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

const DEMO_EMOTIONS: EmotionRecord[] = [
  {
    id: 'e1',
    level: 2,
    subEmotion: null,
    status: '学习中',
    note: '今天高效完成了论文大纲',
    recordDate: getTodayStr(),
    createdAt: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 'e2',
    level: -1,
    subEmotion: 'uncomfortable',
    status: '通勤',
    note: '地铁太挤了，有点烦躁',
    recordDate: getTodayStr(new Date(Date.now() - 86400000)),
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
  {
    id: 'e3',
    level: 3,
    subEmotion: null,
    status: '聚会',
    note: '和老同学聚餐，超级开心！',
    recordDate: getTodayStr(new Date(Date.now() - 172800000)),
    createdAt: new Date(Date.now() - 172800000).toISOString(),
  },
  {
    id: 'e4',
    level: 0,
    subEmotion: null,
    status: '工作',
    note: '平淡的一天',
    recordDate: getTodayStr(new Date(Date.now() - 259200000)),
    createdAt: new Date(Date.now() - 259200000).toISOString(),
  },
  {
    id: 'e5',
    level: -2,
    subEmotion: 'sad',
    status: '深夜',
    note: '想起一些往事，有点难过',
    recordDate: getTodayStr(new Date(Date.now() - 345600000)),
    createdAt: new Date(Date.now() - 345600000).toISOString(),
  },
];

interface EmotionState {
  emotions: EmotionRecord[];
  currentLevel: EmotionLevel;
  currentSubEmotion: SubEmotion;
  addEmotion: (record: Omit<EmotionRecord, 'id' | 'createdAt'>) => void;
  deleteEmotion: (id: string) => void;
  setCurrentLevel: (level: EmotionLevel) => void;
  setCurrentSubEmotion: (sub: SubEmotion) => void;
}

export const useEmotionStore = create<EmotionState>()(
  persist(
    (set) => ({
      emotions: DEMO_EMOTIONS,
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
