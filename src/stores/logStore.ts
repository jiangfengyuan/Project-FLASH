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
  editingId: string | null;
  // Filter state
  startDate: string | null;
  endDate: string | null;
  filterTags: ColorTag[];
  sortBy: 'newest' | 'oldest' | 'tag';
  getFilteredLogs: () => LogItem[];
  getIdeas: () => LogItem[];
  addLog: (content: string, colorTag: ColorTag, category?: Category) => void;
  updateLog: (id: string, updates: Partial<LogItem>) => void;
  deleteLog: (id: string) => void;
  setSearchQuery: (query: string) => void;
  setEditingId: (id: string | null) => void;
  moveToIdea: (id: string) => void;
  // Filter actions
  setDateRange: (start: string | null, end: string | null) => void;
  setFilterTags: (tags: ColorTag[]) => void;
  toggleFilterTag: (tag: ColorTag) => void;
  setSortBy: (sort: 'newest' | 'oldest' | 'tag') => void;
  resetFilters: () => void;
  // Import actions
  importLogs: (logs: LogItem[]) => void;
  overwriteLogs: (logs: LogItem[]) => void;
}

export const useLogStore = create<LogState>()(
  persist(
    (set, get) => ({
      logs: [],
      searchQuery: '',
      editingId: null,
      // Filter state
      startDate: null,
      endDate: null,
      filterTags: [],
      sortBy: 'newest',
      getFilteredLogs: () => {
        const { logs, searchQuery, filterTags, startDate, endDate, sortBy } = get();
        const query = searchQuery.toLowerCase();
        let filtered = logs.filter((log) => {
          if (log.category !== 'log') return false;
          const matchesSearch = !query || log.content.toLowerCase().includes(query);
          const matchesTags = filterTags.length === 0 || filterTags.includes(log.colorTag);
          const matchesStart = !startDate || log.recordDate >= startDate;
          const matchesEnd = !endDate || log.recordDate <= endDate;
          return matchesSearch && matchesTags && matchesStart && matchesEnd;
        });

        if (sortBy === 'oldest') {
          filtered = [...filtered].sort(
            (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
          );
        } else if (sortBy === 'newest') {
          filtered = [...filtered].sort(
            (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
          );
        } else if (sortBy === 'tag') {
          filtered = [...filtered].sort((a, b) => a.colorTag.localeCompare(b.colorTag));
        }

        return filtered;
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
      setEditingId: (id) => set({ editingId: id }),
      moveToIdea: (id) => {
        set((state) => ({
          logs: state.logs.map((log) => (log.id === id ? { ...log, category: 'idea' } : log)),
        }));
      },
      // Filter actions
      setDateRange: (start, end) => set({ startDate: start, endDate: end }),
      setFilterTags: (tags) => set({ filterTags: tags }),
      toggleFilterTag: (tag) =>
        set((state) => {
          const next = state.filterTags.includes(tag)
            ? state.filterTags.filter((t) => t !== tag)
            : [...state.filterTags, tag];
          return { filterTags: next };
        }),
      setSortBy: (sort) => set({ sortBy: sort }),
      resetFilters: () =>
        set({
          searchQuery: '',
          startDate: null,
          endDate: null,
          filterTags: [],
          sortBy: 'newest',
        }),
      // Import actions
      importLogs: (logs) =>
        set((state) => {
          const map = new Map(state.logs.map((l) => [l.id, l]));
          for (const log of logs) map.set(log.id, log);
          return { logs: Array.from(map.values()) };
        }),
      overwriteLogs: (logs) => set({ logs }),
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
