import { useEffect } from 'react';
import { App } from '@capacitor/app';
import { useNavigationStore, TAB_PAGES, type Tab } from '@/stores/navigationStore';

export function useBackButton(exitApp: () => void): void {
  const { currentPage, activeTab, navigateTo } = useNavigationStore();

  useEffect(() => {
    const listener = App.addListener('backButton', ({ canGoBack }) => {
      if (!canGoBack) {
        exitApp();
        return;
      }
      if (TAB_PAGES.includes(currentPage as Tab)) {
        exitApp();
      } else {
        navigateTo(activeTab);
      }
    });

    return () => {
      void listener.then((l) => l.remove());
    };
  }, [currentPage, activeTab, navigateTo, exitApp]);
}
