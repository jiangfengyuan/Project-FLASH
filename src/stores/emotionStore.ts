import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type EmotionLevel = 3 | 2 | 1 | 0 | -1 | -2 | -3;
export type SubEmotion = 'sad' | 'angry' | 'uncomfortable' | null;

export interface EmotionRecord {
  id: string;
  level: EmotionLevel;
  subEmotion: SubEmotion;
  status: string | null;
  note: string | null;
  recordDate: string;
  createdAt: string;
}

const LEVEL_NAMES: Record<EmotionLevel, string> = {
  3: '非常开心',
  2: '很开心',
  1: '开心',
  0: '中性',
  [-1]: '不开心',
  [-2]: '很不开心',
  [-3]: '非常不开心',
};

const LEVEL_COLORS: Record<EmotionLevel, string> = {
  3: '#FFB347',
  2: '#F0D878',
  1: '#90EE90',
  0: '#B0E0E6',
  [-1]: '#B0C4DE',
  [-2]: '#DDA0DD',
  [-3]: '#800080',
};

const DEMO_EMOTIONS: EmotionRecord[] = [
  {
    id: 'e1',
    level: 2,
    subEmotion: null,
    status: '学习中',
    note: '今天高效完成了论文大纲',
    recordDate: new Date().toISOString().split('T')[0],
    createdAt: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 'e2',
    level: -1,
    subEmotion: 'uncomfortable',
    status: '通勤',
    note: '地铁太挤了，有点烦躁',
    recordDate: new Date(Date.now() - 86400000).toISOString().split('T')[0],
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
  {
    id: 'e3',
    level: 3,
    subEmotion: null,
    status: '聚会',
    note: '和老同学聚餐，超级开心！',
    recordDate: new Date(Date.now() - 172800000).toISOString().split('T')[0],
    createdAt: new Date(Date.now() - 172800000).toISOString(),
  },
  {
    id: 'e4',
    level: 0,
    subEmotion: null,
    status: '工作',
    note: '平淡的一天',
    recordDate: new Date(Date.now() - 259200000).toISOString().split('T')[0],
    createdAt: new Date(Date.now() - 259200000).toISOString(),
  },
  {
    id: 'e5',
    level: -2,
    subEmotion: 'sad',
    status: '深夜',
    note: '想起一些往事，有点难过',
    recordDate: new Date(Date.now() - 345600000).toISOString().split('T')[0],
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
  getEmotionsByDate: (date: string) => EmotionRecord[];
  getDominantEmotionForDate: (date: string) => EmotionLevel | null;
}

export const useEmotionStore = create<EmotionState>()(
  persist(
    (set, get) => ({
      emotions: DEMO_EMOTIONS,
      currentLevel: 1,
      currentSubEmotion: null,
      addEmotion: (record) => {
        const newRecord: EmotionRecord = {
          ...record,
          id: Date.now().toString(),
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
      getEmotionsByDate: (date) => {
        return get().emotions.filter((e) => e.recordDate === date);
      },
      getDominantEmotionForDate: (date) => {
        const dayEmotions = get().emotions.filter((e) => e.recordDate === date);
        if (dayEmotions.length === 0) return null;
        const counts = new Map<EmotionLevel, number>();
        dayEmotions.forEach((e) => {
          counts.set(e.level, (counts.get(e.level) || 0) + 1);
        });
        let dominant: EmotionLevel = dayEmotions[0].level;
        let maxCount = 0;
        counts.forEach((count, level) => {
          if (count > maxCount || (count === maxCount && level > dominant)) {
            maxCount = count;
            dominant = level;
          }
        });
        return dominant;
      },
    }),
    {
      name: 'flash-emotions',
    }
  )
);

export { LEVEL_NAMES, LEVEL_COLORS };
