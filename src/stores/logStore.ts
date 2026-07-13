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
      logs: [],
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
          logs: state.logs.map((log) => (log.id === id ? { ...log, category: 'idea' } : log)),
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
