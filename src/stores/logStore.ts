import { create } from 'zustand';
import type { ColorTag, Category } from '@/lib/constants';
import { getTodayStr } from '@/lib/utils';
import { getStorageAdapter } from '@/lib/storage';
import { withStorageRollback, createMutationQueue } from '@/lib/storage/storeHelpers';
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
  // Filter state
  startDate: string | null;
  endDate: string | null;
  filterTags: ColorTag[];
  sortBy: 'newest' | 'oldest' | 'tag';
  addLog: (content: string, colorTag: ColorTag, category?: Category) => Promise<void>;
  updateLog: (id: string, updates: Partial<LogItem>) => Promise<void>;
  deleteLog: (id: string) => Promise<void>;
  setSearchQuery: (query: string) => void;
  // Filter actions
  setDateRange: (start: string | null, end: string | null) => void;
  setFilterTags: (tags: ColorTag[]) => void;
  toggleFilterTag: (tag: ColorTag) => void;
  setSortBy: (sort: 'newest' | 'oldest' | 'tag') => void;
  resetFilters: () => void;
  // Import actions
  overwriteLogs: (logs: LogItem[]) => void;
  flushMutations: () => Promise<void>;
  /**
   * Enqueue an arbitrary async operation against this store's mutation queue.
   * External bulk operations (e.g. Settings import/clear) should use this so
   * they cannot interleave with queued add/update/delete mutations.
   */
  enqueueMutation: (operation: () => Promise<void>) => Promise<void>;
}

const { enqueue: queueMutation, flush: flushMutationQueue } = createMutationQueue();

export const useLogStore = create<LogState>((set, get) => ({
  logs: [],
  booted: false,
  searchQuery: '',
  // Filter state
  startDate: null,
  endDate: null,
  filterTags: [],
  sortBy: 'newest',
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
  flushMutations: flushMutationQueue,
  enqueueMutation: queueMutation,
}));
