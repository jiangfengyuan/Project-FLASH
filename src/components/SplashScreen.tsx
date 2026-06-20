import { useEffect, useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useNavigationStore } from '@/stores/navigationStore';
import { useReducedMotion } from '@/lib/motion';

export default function SplashScreen() {
  const reduced = useReducedMotion();
  const setShowSplash = useNavigationStore((state) => state.setShowSplash);
  const [phase, setPhase] = useState(0);
  const timersRef = useRef<ReturnType<typeof setTimeout>[]>([]);

  useEffect(() => {
    timersRef.current = [
      setTimeout(() => setPhase(1), 400),
      setTimeout(() => setPhase(2), 900),
      setTimeout(() => setPhase(3), 1400),
      setTimeout(() => setPhase(4), 2200),
    ];
    return () => timersRef.current.forEach(clearTimeout);
  }, []);

  const handleSkip = () => {
    timersRef.current.forEach(clearTimeout);
    setPhase(4);
  };

  useEffect(() => {
    if (phase === 4) {
      const timer = setTimeout(() => setShowSplash(false), 600);
      return () => clearTimeout(timer);
    }
  }, [phase, setShowSplash]);

  return (
    <motion.div
      className="fixed inset-0 z-[100] flex flex-col items-center justify-center cursor-pointer"
      style={{ background: '#0a0e1a' }}
      onClick={handleSkip}
      initial={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: reduced ? 0 : 0.4 }}
    >
      <div className="relative w-48 h-48 flex items-center justify-center">
        <AnimatePresence>
          {phase >= 1 && (
            <motion.img
              src="./splash-pencil.jpg"
              alt="Flash"
              className="w-40 h-40 object-contain rounded-3xl"
              initial={{ opacity: 0, scale: reduced ? 1 : 0.6, rotate: reduced ? 0 : -10 }}
              animate={{ opacity: 1, scale: 1, rotate: 0 }}
              exit={{ opacity: 0, scale: reduced ? 1 : 1.1 }}
              transition={{ duration: reduced ? 0 : 0.6, ease: [0.22, 1, 0.36, 1] }}
            />
          )}
        </AnimatePresence>

        <motion.div
          className="absolute inset-0 rounded-full"
          style={{
            background: 'radial-gradient(circle, rgba(100,80,255,0.3) 0%, transparent 70%)',
          }}
          initial={{ opacity: 0, scale: 0.5 }}
          animate={{ opacity: phase >= 1 ? 1 : 0, scale: 1.5 }}
          transition={{ duration: reduced ? 0 : 1 }}
        />
      </div>

      <AnimatePresence>
        {phase >= 3 && (
          <motion.div
            className="mt-8 flex flex-col items-center"
            initial={{ opacity: 0, y: reduced ? 0 : 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: reduced ? 0 : 0.5, ease: 'easeOut' }}
          >
            <h1 className="text-3xl font-semibold text-white tracking-wider">
              <span className="text-slate-400">#</span>flash
            </h1>
            <p className="mt-2 text-sm text-slate-400 tracking-widest">FLASH</p>
            <p className="mt-6 text-xs text-slate-600">闪过即留，一目了然</p>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="absolute bottom-12 left-1/2 -translate-x-1/2 w-32 h-0.5 bg-slate-800 rounded-full overflow-hidden">
        <motion.div
          className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full"
          initial={{ width: '0%' }}
          animate={{ width: phase >= 4 ? '100%' : `${phase * 25}%` }}
          transition={{ duration: reduced ? 0 : 0.5 }}
        />
      </div>

      <motion.p
        className="absolute bottom-6 text-[10px] text-slate-600"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: reduced ? 0 : 1, duration: reduced ? 0 : 0.3 }}
      >
        点击跳过
      </motion.p>
    </motion.div>
  );
}
