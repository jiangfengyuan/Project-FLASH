import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { ColorTag, Category } from '@/lib/constants';
import { getTodayStr } from '@/lib/utils';
export type { ColorTag, Category };

export interface LogItem {
  id: string;
  content: string;
  colorTag: ColorTag;
  category: Category;
  importance: number;
  createdAt: string;
  recordDate: string;
}

const DEMO_LOGS: LogItem[] = [
  {
    id: '1',
    content: '课堂上想到的关于AI辅助学习的创意点子，可以快速记下来了',
    colorTag: 'inspiration',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 3600000).toISOString(),
    recordDate: getTodayStr(),
  },
  {
    id: '2',
    content: '下午3点小组讨论，记得带笔记本',
    colorTag: 'urgent',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 7200000).toISOString(),
    recordDate: getTodayStr(),
  },
  {
    id: '3',
    content: '今天在图书馆看到一本关于认知科学的书，觉得很有意思',
    colorTag: 'idea',
    category: 'idea',
    importance: 2,
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 86400000)),
  },
  {
    id: '4',
    content: '晚上记得去超市买牛奶和面包',
    colorTag: 'daily',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 172800000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 172800000)),
  },
  {
    id: '5',
    content: '心理课的笔记：情绪ABC理论，A是诱发事件，B是信念，C是情绪结果',
    colorTag: 'memo',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 259200000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 259200000)),
  },
];

interface LogState {
  logs: LogItem[];
  searchQuery: string;
  filterTag: ColorTag | null;
  editingId: string | null;
  getFilteredLogs: () => LogItem[];
  getIdeas: () => LogItem[];
  addLog: (content: string, colorTag: ColorTag, category?: Category) => void;
  updateLog: (id: string, updates: Partial<LogItem>) => void;
  deleteLog: (id: string) => void;
  setSearchQuery: (query: string) => void;
  setFilterTag: (tag: ColorTag | null) => void;
  setEditingId: (id: string | null) => void;
  moveToIdea: (id: string) => void;
}

export const useLogStore = create<LogState>()(
  persist(
    (set, get) => ({
      logs: DEMO_LOGS,
      searchQuery: '',
      filterTag: null,
      editingId: null,
      getFilteredLogs: () => {
        const { logs, searchQuery, filterTag } = get();
        return logs.filter((log) => {
          if (log.category !== 'log') return false;
          const matchesSearch =
            !searchQuery || log.content.toLowerCase().includes(searchQuery.toLowerCase());
          const matchesTag = !filterTag || log.colorTag === filterTag;
          return matchesSearch && matchesTag;
        });
      },
      getIdeas: () => {
        return get().logs.filter((log) => log.category === 'idea');
      },
      addLog: (content, colorTag, category = 'log') => {
        const newLog: LogItem = {
          id: crypto.randomUUID(),
          content,
          colorTag,
          category,
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: getTodayStr(),
        };
        set((state) => ({ logs: [newLog, ...state.logs] }));
      },
      updateLog: (id, updates) => {
        set((state) => ({
          logs: state.logs.map((log) => (log.id === id ? { ...log, ...updates } : log)),
        }));
      },
      deleteLog: (id) => {
        set((state) => ({
          logs: state.logs.filter((log) => log.id !== id),
        }));
      },
      setSearchQuery: (query) => set({ searchQuery: query }),
      setFilterTag: (tag) => set({ filterTag: tag }),
      setEditingId: (id) => set({ editingId: id }),
      moveToIdea: (id) => {
        set((state) => ({
          logs: state.logs.map((log) =>
            log.id === id ? { ...log, category: 'idea' as Category } : log
          ),
        }));
      },
    }),
    {
      name: 'flash-logs',
      version: 1,
      partialize: (state) => ({
        logs: state.logs,
      }),
    }
  )
);
