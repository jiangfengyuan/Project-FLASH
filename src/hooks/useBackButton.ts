import { useEffect, useRef } from 'react';
import { App } from '@capacitor/app';
import { Capacitor } from '@capacitor/core';
import { useNavigationStore, TAB_PAGES, type Tab } from '@/stores/navigationStore';

export function useBackButton(exitApp: () => void): void {
  const exitAppRef = useRef(exitApp);

  useEffect(() => {
    exitAppRef.current = exitApp;
  }, [exitApp]);

  useEffect(() => {
    if (!Capacitor.isNativePlatform()) {
      return;
    }

    const listener = App.addListener('backButton', ({ canGoBack }) => {
      if (!canGoBack) {
        exitAppRef.current();
        return;
      }
      const { currentPage, activeTab, navigateTo } = useNavigationStore.getState();
      if (TAB_PAGES.includes(currentPage as Tab)) {
        exitAppRef.current();
      } else {
        navigateTo(activeTab);
      }
    });

    return () => {
      void listener.then((l) => l.remove()).catch(() => {});
    };
  }, []);
}
