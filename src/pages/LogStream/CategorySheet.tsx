import { motion, AnimatePresence } from 'framer-motion';
import { useReducedMotion, springTransition, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_TAP } from '@/lib/haptics';

interface CategorySheetProps {
  open: boolean;
  onClose: () => void;
  onSave: (category: 'log' | 'idea') => void;
  disabled?: boolean;
}

export default function CategorySheet({ open, onClose, onSave, disabled }: CategorySheetProps) {
  const reduced = useReducedMotion();

  const handleSave = (category: 'log' | 'idea') => {
    haptic(HAPTIC_TAP);
    onSave(category);
  };

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={fadeTransition(reduced)}
          className="fixed inset-0 z-[80] flex items-end justify-center"
          onClick={onClose}
          role="dialog"
          aria-modal="true"
          aria-label="选择保存类型"
        >
          <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" />
          <motion.div
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            exit={{ y: 100 }}
            transition={springTransition(reduced)}
            className="relative w-full max-w-md mx-auto p-4 pb-8 space-y-3"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="liquid-glass p-4 space-y-2">
              <p className="text-center text-sm text-slate-400 mb-3">保存为</p>
              <button
                onClick={() => handleSave('log')}
                disabled={disabled}
                className="w-full liquid-glass-pill py-3.5 text-white font-medium text-sm active:scale-[0.98] transition-transform disabled:opacity-40"
              >
                作为 LOG 保存
              </button>
              <button
                onClick={() => handleSave('idea')}
                disabled={disabled}
                className="w-full liquid-glass-pill py-3.5 text-amber-300 font-medium text-sm active:scale-[0.98] transition-transform disabled:opacity-40"
                style={{ background: 'rgba(255,159,67,0.15)' }}
              >
                作为 IDEA 发送
              </button>
            </div>
            <button
              onClick={onClose}
              disabled={disabled}
              className="w-full liquid-glass-pill py-3 text-slate-400 text-sm active:scale-[0.98] transition-transform disabled:opacity-40"
            >
              取消
            </button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
