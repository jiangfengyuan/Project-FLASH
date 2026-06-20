import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type Tab = 'log' | 'idea' | 'calendar' | 'emotion';
export type Page = Tab | 'logFlow' | 'ideaEdit' | 'ideaDetail' | 'settings';

export const TAB_PAGES: Tab[] = ['log', 'idea', 'calendar', 'emotion'];

export function getPageDirection(prevPage: Page, nextPage: Page): number {
  const prevTabIndex = TAB_PAGES.indexOf(prevPage as Tab);
  const nextTabIndex = TAB_PAGES.indexOf(nextPage as Tab);

  // Both pages are tabs: direction follows tab order.
  if (prevTabIndex !== -1 && nextTabIndex !== -1) {
    return Math.sign(nextTabIndex - prevTabIndex);
  }

  // Entering a non-tab page (e.g. log -> logFlow): slide forward.
  if (prevTabIndex !== -1 && nextTabIndex === -1) {
    return 1;
  }

  // Leaving a non-tab page (e.g. logFlow -> log): slide backward relative to active tab.
  if (prevTabIndex === -1 && nextTabIndex !== -1) {
    return -1;
  }

  // Both non-tab pages: no directional preference.
  return 0;
}

interface NavigationState {
  currentPage: Page;
  activeTab: Tab;
  showSplash: boolean;
  direction: number;
  navigateTo: (page: Page) => void;
  setActiveTab: (tab: Tab) => void;
  setShowSplash: (show: boolean) => void;
}

export const useNavigationStore = create<NavigationState>()(
  persist(
    (set) => ({
      currentPage: 'log',
      activeTab: 'log',
      showSplash: true,
      direction: 0,
      navigateTo: (page) =>
        set((state) => {
          const newState: Partial<NavigationState> = {
            currentPage: page,
            direction: getPageDirection(state.currentPage, page),
          };
          if (TAB_PAGES.includes(page as Tab)) {
            newState.activeTab = page as Tab;
          }
          return newState;
        }),
      setActiveTab: (tab) =>
        set((state) => ({
          activeTab: tab,
          currentPage: tab,
          direction: getPageDirection(state.currentPage, tab),
        })),
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
