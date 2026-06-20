import { useEffect, lazy, Suspense, useMemo } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { useNavigationStore, type Page, TAB_PAGES, type Tab } from '@/stores/navigationStore';
import { useReducedMotion } from '@/lib/motion';
import BottomNav from '@/components/BottomNav';
import SplashScreen from '@/components/SplashScreen';
import Toast from '@/components/Toast';

const WaveBackground = lazy(() => import('@/components/WaveBackground'));
const LogStream = lazy(() => import('@/pages/LogStream'));
const LogFlow = lazy(() => import('@/pages/LogFlow'));
const IdeaFlow = lazy(() => import('@/pages/IdeaFlow'));
const Calendar = lazy(() => import('@/pages/Calendar'));
const CurrentEmotion = lazy(() => import('@/pages/CurrentEmotion'));

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

  useEffect(() => {
    if (showSplash) {
      const timer = setTimeout(() => setShowSplash(false), 3000);
      return () => clearTimeout(timer);
    }
  }, [showSplash, setShowSplash]);

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
      <main className={`relative h-full overflow-hidden ${showNav ? 'pb-16' : ''}`}>
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
