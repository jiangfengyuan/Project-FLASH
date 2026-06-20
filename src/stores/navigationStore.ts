import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type Tab = 'log' | 'idea' | 'calendar' | 'emotion';
export type Page = Tab | 'logFlow' | 'ideaEdit' | 'ideaDetail' | 'settings';

interface NavigationState {
  currentPage: Page;
  activeTab: Tab;
  showSplash: boolean;
  navigateTo: (page: Page) => void;
  setActiveTab: (tab: Tab) => void;
  setShowSplash: (show: boolean) => void;
}

export const TAB_PAGES: Tab[] = ['log', 'idea', 'calendar', 'emotion'];

export const useNavigationStore = create<NavigationState>()(
  persist(
    (set) => ({
      currentPage: 'log',
      activeTab: 'log',
      showSplash: true,
      navigateTo: (page) =>
        set(() => {
          const newState: Partial<NavigationState> = { currentPage: page };
          if (TAB_PAGES.includes(page as Tab)) {
            newState.activeTab = page as Tab;
          }
          return newState;
        }),
      setActiveTab: (tab) => set({ activeTab: tab, currentPage: tab }),
      setShowSplash: (show) => set({ showSplash: show }),
    }),
    {
      name: 'flash-navigation',
      version: 1,
      partialize: (state) => ({
        currentPage: state.currentPage,
        activeTab: state.activeTab,
      }),
    }
  )
);
