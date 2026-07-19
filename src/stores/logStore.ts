import { create } from 'zustand';
import type { ColorTag, Category } from '@/lib/constants';
import { getTodayStr } from '@/lib/utils';
import { getStorageAdapter } from '@/lib/storage';
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
  /**
   * False until the initial storage load in App.tsx completes. Main content
   * must not render before this flips true, otherwise the boot-time setState
   * would clobber user mutations made during the splash window.
   */
  booted: boolean;
  searchQuery: string;
  editingId: string | null;
  // Filter state
  startDate: string | null;
  endDate: string | null;
  filterTags: ColorTag[];
  sortBy: 'newest' | 'oldest' | 'tag';
  getFilteredLogs: () => LogItem[];
  getIdeas: () => LogItem[];
  addLog: (content: string, colorTag: ColorTag, category?: Category) => Promise<void>;
  updateLog: (id: string, updates: Partial<LogItem>) => Promise<void>;
  deleteLog: (id: string) => Promise<void>;
  setSearchQuery: (query: string) => void;
  setEditingId: (id: string | null) => void;
  moveToIdea: (id: string) => Promise<void>;
  // Filter actions
  setDateRange: (start: string | null, end: string | null) => void;
  setFilterTags: (tags: ColorTag[]) => void;
  toggleFilterTag: (tag: ColorTag) => void;
  setSortBy: (sort: 'newest' | 'oldest' | 'tag') => void;
  resetFilters: () => void;
  // Import actions
  overwriteLogs: (logs: LogItem[]) => void;
  flushMutations: () => Promise<void>;
}

async function withStorageRollback<T>(
  mutate: () => void,
  persist: () => Promise<T>,
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

let mutationQueue: Promise<unknown> = Promise.resolve();

function queueMutation(operation: () => Promise<void>): Promise<void> {
  const result = mutationQueue.then(operation);
  mutationQueue = result.catch(() => {});
  return result;
}

export const useLogStore = create<LogState>((set, get) => ({
  logs: [],
  booted: false,
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
  addLog: async (content, colorTag, category = 'log') => {
    const newLog: LogItem = {
      id: crypto.randomUUID(),
      content,
      colorTag,
      category,
      importance: 0,
      createdAt: new Date().toISOString(),
      recordDate: getTodayStr(),
    };
    await queueMutation(async () => {
      const previousLogs = get().logs;
      await withStorageRollback(
        () => set((state) => ({ logs: [newLog, ...state.logs] })),
        async () => {
          const storage = await getStorageAdapter();
          await storage.saveLog(newLog);
        },
        () => set({ logs: previousLogs })
      );
    });
  },
  updateLog: async (id, updates) => {
    await queueMutation(async () => {
      const previousLogs = get().logs;
      await withStorageRollback(
        () =>
          set((state) => ({
            logs: state.logs.map((log) => (log.id === id ? { ...log, ...updates } : log)),
          })),
        async () => {
          const storage = await getStorageAdapter();
          const updated = previousLogs.find((log) => log.id === id);
          if (!updated) return;
          const merged = { ...updated, ...updates };
          await storage.saveLog(merged);
        },
        () => set({ logs: previousLogs })
      );
    });
  },
  deleteLog: async (id) => {
    await queueMutation(async () => {
      const previousLogs = get().logs;
      await withStorageRollback(
        () => set((state) => ({ logs: state.logs.filter((log) => log.id !== id) })),
        async () => {
          const storage = await getStorageAdapter();
          await storage.deleteLog(id);
        },
        () => set({ logs: previousLogs })
      );
    });
  },
  setSearchQuery: (query) => set({ searchQuery: query }),
  setEditingId: (id) => set({ editingId: id }),
  moveToIdea: async (id) => {
    await queueMutation(async () => {
      const previousLogs = get().logs;
      await withStorageRollback(
        () =>
          set((state) => ({
            logs: state.logs.map((log) => (log.id === id ? { ...log, category: 'idea' } : log)),
          })),
        async () => {
          const storage = await getStorageAdapter();
          const log = previousLogs.find((l) => l.id === id);
          if (!log) return;
          await storage.saveLog({ ...log, category: 'idea' });
        },
        () => set({ logs: previousLogs })
      );
    });
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
  overwriteLogs: (logs) => set({ logs }),
  flushMutations: async () => {
    await mutationQueue;
  },
}));
