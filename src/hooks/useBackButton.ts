import { useEffect } from 'react';
import { App } from '@capacitor/app';
import { Capacitor } from '@capacitor/core';
import { useNavigationStore, TAB_PAGES, type Tab } from '@/stores/navigationStore';

export function useBackButton(exitApp: () => void): void {
  const { currentPage, activeTab, navigateTo } = useNavigationStore();

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) {
      return;
    }

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
      void listener.then((l) => l.remove()).catch(() => {});
    };
  }, [currentPage, activeTab, navigateTo, exitApp]);
}
