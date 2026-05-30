import { create } from 'zustand';

export type Tab = 'log' | 'idea' | 'calendar' | 'emotion';
export type Page = Tab | 'logFlow' | 'ideaEdit' | 'ideaDetail' | 'settings';

interface AppState {
  currentPage: Page;
  activeTab: Tab;
  showSplash: boolean;
  toast: { message: string; type: 'success' | 'error' | 'info' } | null;
  navigateTo: (page: Page) => void;
  setActiveTab: (tab: Tab) => void;
  setShowSplash: (show: boolean) => void;
  showToast: (message: string, type?: 'success' | 'error' | 'info') => void;
  clearToast: () => void;
}

export const useAppStore = create<AppState>((set) => ({
  currentPage: 'log',
  activeTab: 'log',
  showSplash: true,
  toast: null,
  navigateTo: (page) =>
    set(() => {
      const tabPages: Tab[] = ['log', 'idea', 'calendar', 'emotion'];
      const newState: Partial<AppState> = { currentPage: page };
      if (tabPages.includes(page as Tab)) {
        newState.activeTab = page as Tab;
      }
      return newState;
    }),
  setActiveTab: (tab) => set({ activeTab: tab, currentPage: tab }),
  setShowSplash: (show) => set({ showSplash: show }),
  showToast: (message, type = 'info') => set({ toast: { message, type } }),
  clearToast: () => set({ toast: null }),
}));
