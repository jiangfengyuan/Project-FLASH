import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { useAppStore } from '@/stores/appStore';
import WaveBackground from '@/components/WaveBackground';
import BottomNav from '@/components/BottomNav';
import SplashScreen from '@/components/SplashScreen';
import Toast from '@/components/Toast';
import LogStream from '@/pages/LogStream';
import LogFlow from '@/pages/LogFlow';
import IdeaFlow from '@/pages/IdeaFlow';
import Calendar from '@/pages/Calendar';
import CurrentEmotion from '@/pages/CurrentEmotion';

const pageVariants = {
  initial: { opacity: 0, x: 20 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -20 },
};

const tabPages = ['log', 'idea', 'calendar', 'emotion'];

export default function App() {
  const { currentPage, showSplash, setShowSplash } = useAppStore();

  useEffect(() => {
    if (showSplash) {
      const timer = setTimeout(() => setShowSplash(false), 3000);
      return () => clearTimeout(timer);
    }
  }, [showSplash, setShowSplash]);

  const showNav = tabPages.includes(currentPage);

  const renderPage = () => {
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

  return (
    <div className="h-screen w-screen overflow-hidden relative">
      {/* 3D Wave Background */}
      <WaveBackground />

      {/* Splash Screen */}
      <AnimatePresence>
        {showSplash && <SplashScreen />}
      </AnimatePresence>

      {/* Main Content */}
      <main
        className={`relative z-10 h-full overflow-hidden ${showNav ? 'pb-16' : ''}`}
      >
        <AnimatePresence mode="wait">
          <motion.div
            key={currentPage}
            variants={pageVariants}
            initial="initial"
            animate="animate"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="h-full"
          >
            {renderPage()}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Bottom Navigation */}
      {showNav && <BottomNav />}

      {/* Toast Notifications */}
      <Toast />
    </div>
  );
}
