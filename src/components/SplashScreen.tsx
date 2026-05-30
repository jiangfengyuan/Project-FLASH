import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useAppStore } from '@/stores/appStore';

export default function SplashScreen() {
  const { setShowSplash } = useAppStore();
  const [phase, setPhase] = useState(0);

  useEffect(() => {
    const timers = [
      setTimeout(() => setPhase(1), 400),
      setTimeout(() => setPhase(2), 900),
      setTimeout(() => setPhase(3), 1400),
      setTimeout(() => setPhase(4), 2200),
    ];
    return () => timers.forEach(clearTimeout);
  }, []);

  const handleSkip = () => {
    setPhase(4);
    setTimeout(() => setShowSplash(false), 600);
  };

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col items-center justify-center cursor-pointer"
      style={{ background: '#0a0e1a' }}
      onClick={handleSkip}
    >
      <div className="relative w-48 h-48 flex items-center justify-center">
        {/* Pencil image */}
        <AnimatePresence>
          {phase >= 1 && (
            <motion.img
              src="/splash-pencil.jpg"
              alt="Flash"
              className="w-40 h-40 object-contain rounded-3xl"
              initial={{ opacity: 0, scale: 0.6, rotate: -10 }}
              animate={{ opacity: 1, scale: 1, rotate: 0 }}
              exit={{ opacity: 0, scale: 1.1 }}
              transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
            />
          )}
        </AnimatePresence>

        {/* Glow effect */}
        <motion.div
          className="absolute inset-0 rounded-full"
          style={{
            background: 'radial-gradient(circle, rgba(100,80,255,0.3) 0%, transparent 70%)',
          }}
          initial={{ opacity: 0, scale: 0.5 }}
          animate={{ opacity: phase >= 1 ? 1 : 0, scale: 1.5 }}
          transition={{ duration: 1 }}
        />
      </div>

      {/* Brand text */}
      <AnimatePresence>
        {phase >= 3 && (
          <motion.div
            className="mt-8 flex flex-col items-center"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: 'easeOut' }}
          >
            <h1 className="text-3xl font-semibold text-white tracking-wider">
              <span className="text-slate-400">#</span>flash
            </h1>
            <p className="mt-2 text-sm text-slate-400 tracking-widest">FLASH</p>
            <p className="mt-6 text-xs text-slate-600">闪过即留，一目了然</p>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Progress bar */}
      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 w-32 h-0.5 bg-slate-800 rounded-full overflow-hidden">
        <motion.div
          className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full"
          initial={{ width: '0%' }}
          animate={{ width: phase >= 4 ? '100%' : `${phase * 25}%` }}
          transition={{ duration: 0.5 }}
        />
      </div>

      {/* Skip hint */}
      <motion.p
        className="absolute bottom-6 text-[10px] text-slate-600"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
      >
        点击跳过
      </motion.p>
    </div>
  );
}
