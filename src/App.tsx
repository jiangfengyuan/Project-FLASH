import { useEffect, useRef, lazy, Suspense, useMemo } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { App as CapacitorApp } from '@capacitor/app';
import { useNavigationStore, type Page, TAB_PAGES, type Tab } from '@/stores/navigationStore';
import { useReducedMotion } from '@/lib/motion';
import { getPlatform } from '@/lib/platform';
import { useSafeArea } from '@/hooks/useSafeArea';
import { useBackButton } from '@/hooks/useBackButton';
import { useThemeStore } from '@/stores/themeStore';
import { useToastStore } from '@/stores/toastStore';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { getStorageAdapter } from '@/lib/storage';
import { DEMO_LOGS, DEMO_EMOTIONS } from '@/data/demo';
import BottomNav from '@/components/BottomNav';
import SplashScreen from '@/components/SplashScreen';
import Toast from '@/components/Toast';

const WaveBackground = lazy(() => import('@/components/WaveBackground'));
const LogStream = lazy(() => import('@/pages/LogStream'));
const LogFlow = lazy(() => import('@/pages/LogFlow'));
const IdeaFlow = lazy(() => import('@/pages/IdeaFlow'));
const Calendar = lazy(() => import('@/pages/Calendar'));
const CurrentEmotion = lazy(() => import('@/pages/CurrentEmotion'));
const Settings = lazy(() => import('@/pages/Settings'));

const PageLoader = () => (
  <div className="h-full flex items-center justify-center">
    <div className="w-8 h-8 rounded-full border-2 border-white/20 border-t-white/60 animate-spin" />
  </div>
);

const renderPage = (currentPage: Page) => {
  switch (currentPage) {
    case 'log':
      return <LogStream />;
    case 'logFlow':
      return <LogFlow />;
    case 'idea':
      return <IdeaFlow />;
    case 'calendar':
      return <Calendar />;
    case 'emotion':
      return <CurrentEmotion />;
    case 'settings':
      return <Settings />;
    default:
      return <LogStream />;
  }
};

export default function App() {
  const reduced = useReducedMotion();
  const currentPage = useNavigationStore((state) => state.currentPage);
  const showSplash = useNavigationStore((state) => state.showSplash);
  const setShowSplash = useNavigationStore((state) => state.setShowSplash);
  const direction = useNavigationStore((state) => state.direction);

  useSafeArea();
  useBackButton(() => {
    // On Android, App.exitApp() is available via @capacitor/app.
    // The hook only registers on native platforms, so this is safe on web.
    CapacitorApp.exitApp().catch(() => {});
  });
  const resolved = useThemeStore((s) => s.resolved);

  useEffect(() => {
    const root = document.documentElement;
    if (resolved === 'dark') {
      root.classList.add('dark');
      root.style.colorScheme = 'dark';
    } else {
      root.classList.remove('dark');
      root.style.colorScheme = 'light';
    }
  }, [resolved]);

  useEffect(() => {
    const platform = getPlatform();
    document.documentElement.classList.add(`platform-${platform}`);
    return () => {
      document.documentElement.classList.remove(`platform-${platform}`);
    };
  }, []);

  useEffect(() => {
    if (showSplash) {
      const timer = setTimeout(() => setShowSplash(false), 3000);
      return () => clearTimeout(timer);
    }
  }, [showSplash, setShowSplash]);

  const bootedRef = useRef(false);
  const showToast = useToastStore((s) => s.showToast);

  useEffect(() => {
    if (bootedRef.current) return;
    bootedRef.current = true;

    void (async () => {
      try {
        const storage = await getStorageAdapter();
        const [logs, emotions] = await Promise.all([storage.getLogs(), storage.getEmotions()]);
        useLogStore.setState({ logs });
        useEmotionStore.setState({ emotions });

        if (import.meta.env.DEV) {
          if (useLogStore.getState().logs.length === 0) {
            useLogStore.setState({ logs: DEMO_LOGS });
            await storage.saveLogs(DEMO_LOGS);
          }
          if (useEmotionStore.getState().emotions.length === 0) {
            useEmotionStore.setState({ emotions: DEMO_EMOTIONS });
            await storage.saveEmotions(DEMO_EMOTIONS);
          }
        }
      } catch (error) {
        console.error('App boot failed', error);
        showToast('本地存储初始化失败，数据仅保留在内存中', 'error');
      }
    })();
  }, [showToast]);

  const pageVariants = useMemo(
    () => ({
      initial: { opacity: 0, x: reduced ? 0 : direction * 24 },
      animate: { opacity: 1, x: 0 },
      exit: { opacity: 0, x: reduced ? 0 : direction * -24 },
    }),
    [reduced, direction]
  );

  const showNav = TAB_PAGES.includes(currentPage as Tab);

  return (
    <div className="h-screen w-screen overflow-hidden relative">
      {/* Background */}
      <Suspense fallback={null}>
        <WaveBackground />
      </Suspense>

      {/* Main Content */}
      <main
        className={`relative h-full overflow-hidden ${
          showNav
            ? 'pb-[calc(4rem+env(safe-area-inset-bottom))]'
            : 'pb-[env(safe-area-inset-bottom)]'
        }`}
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={currentPage}
            variants={pageVariants}
            initial="initial"
            animate="animate"
            exit="exit"
            transition={{ duration: reduced ? 0 : 0.28, ease: 'easeInOut' }}
            className="h-full"
          >
            <Suspense fallback={<PageLoader />}>{renderPage(currentPage)}</Suspense>
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Bottom Navigation */}
      {showNav && <BottomNav />}

      {/* Toast Notifications */}
      <Toast />

      {/* Splash Screen - highest z-index */}
      <AnimatePresence>{showSplash && <SplashScreen />}</AnimatePresence>
    </div>
  );
}
